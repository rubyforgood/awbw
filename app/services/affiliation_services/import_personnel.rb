module AffiliationServices
  # Round one of ADR-0011: each FileMaker Personnel row becomes a Facilitator affiliation at the
  # one org carrying its project's code. A row the ADR leaves an open question about is skipped
  # with its reason, for staff to review, rather than guessed at.
  #
  # Activity: each new affiliation keeps its one create event, dated when FileMaker entered the
  # row and credited to who entered it; every other event the run would log is dropped, so a
  # bulk run doesn't write thousands of them. The task logs one summary event for the run.
  class ImportPersonnel
    include FilemakerValues

    OUTCOMES = %i[created linked merged already_imported skipped failed].freeze
    BATCH_SIZE = 500
    ACTIVE = "active"
    INACTIVE = "inactive"
    PRIMARY_ROLES = %w[leader leaders liaison].freeze
    EARLIEST_START = Date.new(1990, 1, 1)
    COMMENT_TOPIC = "FileMaker import"
    PERSONNEL_CODE = /\APS/i
    SOURCE = "fm_import_personnel"
    CREATE_EVENT = "create.affiliation"

    attr_reader :results, :skip_reasons, :roles, :statuses

    def unmatched_staff = @staff.unmatched

    def initialize(progress: nil)
      @progress = progress
      @results = OUTCOMES.index_with { [] }
      @skip_reasons = Hash.new(0)
      @roles = Hash.new(0)
      @statuses = Hash.new(0)
      @created = {}
      @trackers = {}
    end

    def call
      load_indexes
      read = 0
      Current.set(source: Current.source || SOURCE) do
        ordered_rows.each_slice(BATCH_SIZE) do |rows|
          ActiveRecord::Base.transaction(requires_new: true) do
            ActiveRecord::Base.no_touching { rows.each { |row| import_row(row) } }
            log_creations
          end
          read += rows.size
          @progress&.call(read)
        end
      end
      self
    end

    private

    def load_indexes
      @people = FilemakerCodeIndex.new(Person)
      @organizations = FilemakerCodeIndex.new(Organization)
      @imported = FilemakerCodeIndex.new(Affiliation)
      @projects = FmProject.all.index_by(&:fm_id)
      @staff = StaffTranslation.new
      @import_user_id = Setting.import_user&.id
    end

    # Active rows first, then newest first, so when one person has several rows at an org the
    # current stretch is the one that links to a row the portal already holds.
    def ordered_rows
      FmPersonnel.all.sort_by do |row|
        [ status(row) == ACTIVE ? 0 : 1, -(parse_date(row.data["DateEntered"])&.jd || 0), row.fm_id ]
      end
    end

    def import_row(row)
      data = row.data
      label = "#{row.fm_id} #{data["Name"].to_s.squish}".squish
      return record(:already_imported, label) if @imported.include?(row.fm_id)

      tally(data)
      reason, detail = question(row)
      return skip(label, reason, detail) if reason

      place(row, label)
    end

    # Why the ADR can't import this row yet, as [reason, detail], or nil when it can.
    def question(row)
      data = row.data
      start = parse_date(data["DateEntered"])
      return [ "status is neither Active nor Inactive", data["Status"].to_s.squish.presence || "blank" ] unless status(row)
      return [ "no readable start date", data["DateEntered"].presence ] unless start
      return [ "start date before #{EARLIEST_START.year}", start.iso8601 ] if start < EARLIEST_START
      return [ "start date in the future", start.iso8601 ] if start > Date.current
      return person_question(data["PersonID"]) if person_id(row).nil?
      return organization_question(data["ProjectID"]) if organization_id(row).nil?

      finish = end_date(row)
      return [ "Active in FileMaker, but its project is closed", finish.iso8601 ] if status(row) == ACTIVE && finish
      [ "project closed before the row was entered", finish.iso8601 ] if finish && finish < start
    end

    def person_question(code)
      return [ "names no person" ] if code.blank?

      [ @people.ids(code).empty? ? "person wasn't imported" : "person code is on several people", code ]
    end

    def organization_question(code)
      return [ "names no project" ] if code.blank?

      [ @organizations.ids(code).empty? ? "no org carries the project code" : "project code is on several orgs", code ]
    end

    def place(row, label)
      person_id = person_id(row)
      organization_id = organization_id(row)
      facilitators = Affiliation.facilitators.where(person_id:, organization_id:).order(:id).to_a
      attributes = attributes_for(row)

      match = facilitators.find { |affiliation| linkable?(affiliation, attributes) }
      return link(match, row, label, attributes) if match

      twin = facilitators.find { |affiliation| identical?(affiliation, attributes) }
      return merge(twin, row, label) if twin

      disagreeing = facilitators.find { |affiliation| dates_agree?(affiliation, attributes) && open?(affiliation) != open_attributes?(attributes) }
      return skip(label, *status_disagreement(disagreeing, attributes)) if disagreeing
      if open_attributes?(attributes) && (other = facilitators.find { |affiliation| open?(affiliation) })
        return skip(label, "Active in FileMaker, and the portal has an open Facilitator affiliation there with other dates", "##{other.id}")
      end

      create(row, label, person_id, organization_id, attributes)
    end

    def attributes_for(row)
      active = status(row) == ACTIVE
      {
        title: Affiliation::FACILITATOR_TITLE,
        start_date: parse_date(row.data["DateEntered"]),
        end_date: active ? nil : end_date(row),
        inactive: !active,
        primary_contact: primary_contact?(row)
      }
    end

    def linkable?(affiliation, attributes)
      affiliation.filemaker_codes.none? { |code| code.match?(PERSONNEL_CODE) } &&
        dates_agree?(affiliation, attributes) &&
        open?(affiliation) == open_attributes?(attributes)
    end

    def dates_agree?(affiliation, attributes)
      start = affiliation.start_date || attributes[:start_date]
      finish = affiliation.end_date || attributes[:end_date]
      same_or_blank?(affiliation.start_date, attributes[:start_date]) &&
        same_or_blank?(affiliation.end_date, attributes[:end_date]) &&
        (start.nil? || finish.nil? || start <= finish)
    end

    def same_or_blank?(left, right)
      left.nil? || right.nil? || left == right
    end

    def identical?(affiliation, attributes)
      affiliation.start_date == attributes[:start_date] &&
        affiliation.end_date == attributes[:end_date] &&
        affiliation.inactive? == attributes[:inactive]
    end

    def open?(affiliation)
      !affiliation.inactive? && (affiliation.end_date.nil? || affiliation.end_date >= Date.current)
    end

    def open_attributes?(attributes)
      !attributes[:inactive]
    end

    def status_disagreement(affiliation, attributes)
      reason = if open_attributes?(attributes)
        "Active in FileMaker, but the portal's Facilitator affiliation there has ended"
      else
        "ended in FileMaker, but the portal's Facilitator affiliation there is open"
      end
      [ reason, "##{affiliation.id}" ]
    end

    def link(affiliation, row, label, attributes)
      affiliation.filemaker_code = Affiliation.join_filemaker_codes(affiliation.filemaker_code, row.fm_id)
      affiliation.start_date ||= attributes[:start_date]
      affiliation.end_date ||= attributes[:end_date]
      affiliation.primary_contact = true if attributes[:primary_contact]
      return failed(affiliation, label) unless affiliation.save

      note(affiliation, row)
      @imported.add(row.fm_id, affiliation.id)
      record(:linked, "#{label} → affiliation ##{affiliation.id}")
    end

    def merge(affiliation, row, label)
      affiliation.filemaker_code = Affiliation.join_filemaker_codes(affiliation.filemaker_code, row.fm_id)
      affiliation.primary_contact = true if primary_contact?(row)
      return failed(affiliation, label) unless affiliation.save

      note(affiliation, row)
      @imported.add(row.fm_id, affiliation.id)
      record(:merged, "#{label} → affiliation ##{affiliation.id}")
    end

    def create(row, label, person_id, organization_id, attributes)
      created_at = attributes[:start_date].in_time_zone
      affiliation = Affiliation.new(
        **attributes, person_id:, organization_id:, filemaker_code: row.fm_id, inactive_supplied: true,
        created_by_id: @staff.user_id_for(row.data["EnteredBy"]) || @import_user_id,
        updated_by_id: @staff.user_id_for(row.data["ModifiedBy"]) || @import_user_id,
        created_at:, updated_at: parse_date(row.data["DateTimeModified"])&.in_time_zone || created_at
      )
      return failed(affiliation, label) unless affiliation.save

      note(affiliation, row)
      @imported.add(row.fm_id, affiliation.id)
      @created[affiliation.id] = affiliation
      record(:created, "#{label} → affiliation ##{affiliation.id}")
    end

    def log_creations
      Analytics::LifecycleBuffer.store.each do |payload|
        next unless payload[:name] == CREATE_EVENT

        affiliation = @created[payload.dig(:properties, :resource_id)]
        next unless affiliation

        tracker_for(affiliation.created_by_id).track(payload[:name], payload[:properties], time: affiliation.created_at)
      end
    ensure
      Analytics::LifecycleBuffer.store.clear
      @created.clear
    end

    def tracker_for(user_id)
      @trackers[user_id] ||= Ahoy::Tracker.new(user: user_id && User.find_by(id: user_id))
    end

    def note(affiliation, row)
      data = row.data
      body = "FileMaker Personnel #{row.fm_id} on project #{data["ProjectID"]}: " \
             "role #{data["Role"].to_s.squish.presence || "(blank)"}, status #{data["Status"].to_s.squish}."
      notes = data["Notes"].to_s.squish
      body += " Notes: \"#{notes}\"" if notes.present?
      affiliation.comments.create!(topic: COMMENT_TOPIC, body:)
    end

    def status(row)
      value = row.data["Status"].to_s.squish.downcase
      value if [ ACTIVE, INACTIVE ].include?(value)
    end

    def primary_contact?(row)
      PRIMARY_ROLES.include?(row.data["Role"].to_s.squish.downcase)
    end

    def end_date(row)
      project = @projects[row.data["ProjectID"].to_s.strip]
      return unless project

      parse_date(project.data["CloseDate"]) || parse_date(project.data["EndDate"])
    end

    def person_id(row)
      ids = @people.ids(row.data["PersonID"].to_s)
      ids.first if ids.one?
    end

    def organization_id(row)
      ids = @organizations.ids(row.data["ProjectID"].to_s)
      ids.first if ids.one?
    end

    def tally(data)
      @roles[data["Role"].to_s.squish.presence || "(blank)"] += 1
      @statuses[data["Status"].to_s.squish.presence || "(blank)"] += 1
    end

    def skip(label, reason, detail = nil)
      @skip_reasons[reason] += 1
      record(:skipped, [ "#{label}: #{reason}", detail ].compact.join(" — "))
    end

    def failed(affiliation, label)
      record(:failed, "#{label}: #{affiliation.errors.full_messages.to_sentence.presence || "not saved"}")
    end

    def record(outcome, message)
      @results[outcome] << message
      nil
    end
  end
end
