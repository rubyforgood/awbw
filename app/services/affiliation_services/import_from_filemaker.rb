module AffiliationServices
  # Turns the FileMaker archive's ties between people and organizations into affiliations
  # (ADR-0008), after the Rolodex and organizations passes have made both ends. Reads, in
  # order:
  #
  #   1. Personnel (FmPersonnel) — a person staffing a project's art program becomes a
  #      Facilitator affiliation, dated from when the row was entered to when the project
  #      closed, with a comment naming the role FileMaker gave. Only a Leader or Liaison is a
  #      primary contact — turned on for a Facilitator row the portal already had. It links
  #      an existing Facilitator row only when their dates agree (#same_dates); other dates
  #      are a separate stretch and become their own affiliation. Each carries the row's PrsnlRecID as its filemaker_code. A row
  #      whose project wasn't imported lands at the organization on the person's Rolodex
  #      card; one naming no person — or only an agency's own card — gets AWBW Placeholder
  #      where nothing else affiliates anyone.
  #   2. People-to-organizations (FmPeopleToOrganization) — a job at an organization, with
  #      its title, carrying the row's RecordID.
  #   3. The Rolodex card itself (FmRolodex) — the organization its OrgID (or its typed
  #      organization name) names, with its Title, and its work addresses: each lands on
  #      the organization it belongs to and the person's affiliations there point at it.
  #      A work address no organization can be found for stays with the person.
  #
  # People are found by their Rolodex code, organizations by the project or organization
  # code the earlier pass gave them. A row whose person or organization wasn't imported is
  # skipped and reported. An existing affiliation of the same person, organization and
  # title is linked rather than duplicated: it takes the row's code and fills its blank
  # dates.
  #
  # A Personnel or people-to-organizations row whose notes say the person is no longer with
  # the organization ends its affiliation, and the note comes along as a comment.
  #
  # None of these is minted from a training, so event_registration_id stays NULL: the
  # reconcile page treats them as hand-entered rows.
  class ImportFromFilemaker
    include FilemakerValues

    OUTCOMES = %i[created linked already_imported skipped failed].freeze
    BATCH_SIZE = 1_000
    # Personnel Status values that mean the person still staffs the program. Anything else —
    # Inactive, Pending, Suspended, a blank, or two values typed over each other — reads as
    # ended, since over-reporting active programs would skew program status.
    ACTIVE_STATUSES = %w[active].freeze
    # Every Personnel role is a Facilitator, the shape prod's January 2026 conversion gave the
    # old app's roles. Only a role FileMaker names as Leader or Liaison makes a primary contact.
    PRIMARY_ROLES = %w[leader leaders liaison].freeze
    LEFT_NOTE = /\bno longer (with|at|works|employed)\b/i
    ROLE_COMMENT_TOPIC = "FileMaker import"
    # Stands in where a Personnel row names a project but no person.
    PLACEHOLDER_NAME = { first_name: "AWBW", last_name: "Placeholder" }.freeze

    attr_reader :results, :statuses, :roles

    def unmatched_addresses = @address_attributes.unmatched
    def unmatched_staff = @staff.unmatched

    def initialize(fm_ids: nil, progress: nil, run: nil)
      @fm_ids = fm_ids.presence&.to_set
      @progress = progress
      @run = run
      @results = OUTCOMES.index_with { [] }
      @statuses = Hash.new(0)
      @roles = Hash.new(0)
      @staff = StaffTranslation.new
      @import_user_id = Setting.import_user&.id
      @address_attributes = FmAddressAttributes.new
      @name_matcher = OrganizationServices::NameMatcher.new
    end

    def call
      @tracker = Ahoy::Tracker.new
      @people = FilemakerCodeIndex.new(Person)
      @organizations = FilemakerCodeIndex.new(Organization)
      @affiliations = FilemakerCodeIndex.new(Affiliation)
      @projects = FmProject.all.index_by(&:fm_id)
      @personnel_ids = FmPersonnel.pluck(:fm_id).to_set
      @job_ids = FmPeopleToOrganization.pluck(:fm_id).to_set
      @cards = FmRolodex.where(fm_id: FmPersonnel.distinct.pluck(Arel.sql("JSON_UNQUOTE(JSON_EXTRACT(data, '$.PersonID'))")).compact_blank)
                        .index_by(&:fm_id)
      @unstaffed = []
      @read = 0

      each_batch(named(FmPersonnel.all)) { |row| import_personnel(row) }
      each_batch(named(FmPeopleToOrganization.all)) { |row| import_job(row) }
      addresses = FmRolodex.contact_index(FmAddress)
      phones = FmRolodex.contact_index(FmPhoneNumber)
      each_batch(named(FmRolodex.all)) { |rolodex| import_rolodex(rolodex.preload_contacts(addresses:, phone_numbers: phones)) }
      in_batch(@unstaffed) { |row, organization, label| import_unstaffed(row, organization, label) }
      self
    end

    private

    # FM_IDS names the archive rows to read, by their own ID — a personnel record, a
    # people-to-organizations record, or a Rolodex card.
    def named(scope)
      @fm_ids ? scope.where(fm_id: @fm_ids.to_a) : scope
    end

    # Each batch commits on its own, so a run that stops partway keeps what it finished.
    # Its activity events, tagged with the run, commit with it — UndoRolodexImport reads them.
    # Untouched, so a new affiliation doesn't stamp its person as edited now.
    def each_batch(scope, &import)
      scope.find_in_batches(batch_size: BATCH_SIZE) do |batch|
        in_batch(batch, &import)
        @progress&.call(@read += batch.size)
      end
    end

    def in_batch(rows, &import)
      ActiveRecord::Base.transaction(requires_new: true) do
        ActiveRecord::Base.no_touching do
          Analytics::LifecycleBuffer.tagging(@run ? { import_run: @run } : {}) { rows.each(&import) }
        end
        Analytics::LifecycleBuffer.flush_to(@tracker)
      end
    end

    def import_personnel(row)
      data = row.data
      label = "#{row.fm_id} #{data["Name"].to_s.squish}".squish
      return record(:already_imported, label) if @affiliations.include?(row.fm_id)

      card = @cards[data["PersonID"].to_s]
      organization = organization_for(data["ProjectID"]) || card_organization(card)
      return record(:skipped, "#{label}: #{missing_organization(data, card)}") unless organization

      people = @people.records(data["PersonID"])
      return @unstaffed << [ row, organization, label ] if data["PersonID"].blank? || (people.empty? && card&.agency?)
      return record(:skipped, "#{label}: person #{data["PersonID"]} wasn't imported") if people.empty?

      left_on = left_on(data)
      dates = personnel_dates(data, @projects[data["ProjectID"].to_s], left_on:)
      role = data["Role"].to_s.squish
      attributes = dates.merge(primary_contact: primary_contact?(role))
      people.each do |person|
        affiliation = affiliate(person, organization, row, label, title: Affiliation::FACILITATOR_TITLE, attributes:, codes: @personnel_ids, dated: true)
        next unless affiliation

        note_role(affiliation, row, role) if role.present?
        note_left(affiliation, "Personnel #{row.fm_id}", data["Notes"], left_on) if left_on
      end
    end

    # A row whose project wasn't imported (or names none) lands at the organization on the
    # person's Rolodex card — the one its OrgID names, else the one its typed name means,
    # which the organizations pass created when nothing answered to it.
    def card_organization(card)
      return unless card

      organization_for(card.data["OrgID"]) || named_organization(card.data["Organization"])
    end

    def missing_organization(data, card)
      project = data["ProjectID"].presence
      prefix = project ? "project #{project} wasn't imported" : "no project"
      return "#{prefix}, and no Rolodex card for person #{data["PersonID"].presence || "(none)"}" unless card
      return "#{prefix}, and the person's Rolodex card names #{card.data["OrgID"]}, retired in FileMaker" if retired_record?(card.data["OrgID"])

      named = card.data["Organization"].to_s.squish.presence || card.data["OrgID"].presence
      return "#{prefix}, and the person's Rolodex card names no organization" unless named

      "#{prefix}, and the person's Rolodex card names #{named}, which wasn't imported"
    end

    # A Personnel row naming no one still records that the program ran. Read last, once every
    # other row has had its say, so the placeholder only stands in at an organization nothing
    # else affiliates anyone with — one placeholder there is enough.
    def import_unstaffed(row, organization, label)
      if organization.affiliations.exists?
        return record(:skipped, "#{label}: names no person, and organization ##{organization.id} already has affiliations")
      end

      dates = personnel_dates(row.data, @projects[row.data["ProjectID"].to_s])
      affiliation = affiliate(placeholder_person, organization, row, label, title: Affiliation::FACILITATOR_TITLE,
                              attributes: dates.merge(primary_contact: false), codes: @personnel_ids, dated: true)
      return unless affiliation

      affiliation.comments.create!(topic: ROLE_COMMENT_TOPIC,
                                   body: "FileMaker Personnel #{row.fm_id} names no person, so #{PLACEHOLDER_NAME.values.join(" ")} " \
                                         "stands in to keep the program's FileMaker history.")
    end

    def placeholder_person
      @placeholder_person ||= Person.where("LOWER(first_name) = ? AND LOWER(last_name) = ?", *PLACEHOLDER_NAME.values.map(&:downcase))
                                    .order(:id).first ||
                              Person.create!(**PLACEHOLDER_NAME, created_by_id: @import_user_id, updated_by_id: @import_user_id)
    end

    # Every role FileMaker gave folds into Facilitator, so the affiliation keeps the word —
    # and says when the import turned on primary contact for a row the portal already had.
    def note_role(affiliation, row, role)
      flipped = !affiliation.previously_new_record? && affiliation.saved_change_to_primary_contact?
      affiliation.comments.create!(topic: ROLE_COMMENT_TOPIC,
                                   body: "Marked as #{role} in FileMaker (Personnel #{row.fm_id}) at the time of the FileMaker import." \
                                         "#{" Primary contact turned on." if flipped}")
    end

    def primary_contact?(role)
      primary = PRIMARY_ROLES.include?(role.downcase)
      @roles["#{role.presence || "(blank)"} → Facilitator#{", primary contact" if primary}"] += 1
      primary
    end

    # Personnel rows carry no dates of their own: the assignment starts when it was entered
    # and ends when its project closed, else when its notes say the person left. A status
    # that isn't active ends it now, undated.
    def personnel_dates(data, project, left_on: nil)
      status = data["Status"].to_s.squish
      active = ACTIVE_STATUSES.include?(status.downcase)
      @statuses["#{status.presence || "(blank)"} → #{active ? "active" : "ended"}"] += 1
      start_date = parse_date(data["DateEntered"])
      end_date = (project && (parse_date(project.data["CloseDate"]) || parse_date(project.data["EndDate"]))) || left_on
      end_date = nil if start_date && end_date && end_date < start_date
      { start_date:, end_date:, inactive: !active || left_on.present? }
    end

    # FileMaker never recorded when the person left, so it's dated the day staff last saved the
    # row — the day it was known they were gone.
    def left_on(data)
      return unless data["Notes"].to_s.match?(LEFT_NOTE)

      modified_on(data) || Date.current
    end

    def note_left(affiliation, source, notes, left_on)
      ended = " The actual end date isn't known; it's set to #{left_on.iso8601}, the day FileMaker last saved this note, since by then they were no longer there." if affiliation.end_date == left_on
      affiliation.comments.create!(topic: ROLE_COMMENT_TOPIC, body: "FileMaker #{source} notes: \"#{notes.to_s.squish}\".#{ended}")
    end

    def import_job(row)
      data = row.data
      label = "#{row.fm_id} #{data["PersonID"]} at #{data["OrgID"]}"
      return record(:already_imported, label) if @affiliations.include?(row.fm_id)

      people = @people.records(data["PersonID"])
      organization = organization_for(data["OrgID"])
      return record(:skipped, "#{label}: person wasn't imported") if people.empty?
      return record(:skipped, "#{label}: organization wasn't imported") unless organization

      left_on = left_on(data)
      attributes = left_on ? { end_date: left_on, inactive: true } : {}
      people.each do |person|
        affiliation = affiliate(person, organization, row, label, title: clip(data["Title"].to_s.squish), attributes:, codes: @job_ids)
        note_left(affiliation, "People-to-organizations #{row.fm_id}", data["Notes"], left_on) if affiliation && left_on
      end
    end

    # The Rolodex card names the person's organization and their title there, and lists the
    # work addresses the people pass left for this one.
    def import_rolodex(rolodex)
      data = rolodex.data
      work = rolodex.addresses.select { |address| rolodex.organization_address?(address) }
      return if flag?(data["Delete"]) || (data["OrgID"].blank? && data["Organization"].blank? && work.empty?)

      label = "#{rolodex.fm_id} #{rolodex.name}"
      people = @people.records(rolodex.fm_id)
      return record(:skipped, "#{label}: person wasn't imported") if people.empty?

      organization = organization_for(data["OrgID"]) || named_organization(data["Organization"])
      if organization.nil? && (data["OrgID"].present? || data["Organization"].present?)
        record(:skipped, "#{label}: organization #{data["OrgID"].presence || data["Organization"].squish} wasn't found")
      end
      title = clip(data["Title"].to_s.squish)
      people.each do |person|
        next unless organization
        next if title.blank? && person.affiliations.exists?(organization:)

        affiliate(person, organization, rolodex, label, title:, attributes: {}, codes: nil)
      end
      place_work_addresses(rolodex, people, organization, work, label)
    end

    def named_organization(name)
      name = name.to_s.squish
      @name_matcher.call(name)&.organization if name.present?
    end

    # The affiliation this row describes: one the person already has at the organization
    # with the same title is linked, otherwise one is created. `codes` is the set of IDs
    # the row's own table holds — an affiliation already carrying another of them records
    # a different row (another stint on the same project), so it's never the match. A row
    # with no code of its own (the Rolodex card) only fills in what's missing.
    def affiliate(person, organization, row, label, title:, attributes:, codes:, dated: false)
      existing = person.affiliations.where(organization:).to_a
      candidates = existing.select { |affiliation| same_title?(affiliation.title, title) && !records_another_row?(affiliation, codes) }
      match = dated ? same_dates(candidates, attributes) : candidates.first
      match ||= existing.find { |affiliation| affiliation.title.blank? } if title.present? && codes.nil?
      return link(match, row, label, title:, attributes:, codes:) if match

      create(person, organization, row, label, title:, attributes:, code: codes && row.fm_id)
    end

    # A Personnel row links only an affiliation whose dates agree with it — each the same, or
    # blank on one side — and that still reads start-before-end once the blanks fill. Any other
    # dates are a separate stretch, so the row becomes its own affiliation. Identical dates win,
    # then the one sharing the most.
    def same_dates(candidates, dates)
      candidates.select { |affiliation| dates_agree?(affiliation, dates) }
                .min_by { |affiliation| [ identical_dates?(affiliation, dates) ? 0 : 1, -shared_dates(affiliation, dates) ] }
    end

    def dates_agree?(affiliation, dates)
      starts = affiliation.start_date || dates[:start_date]
      ends = affiliation.end_date || dates[:end_date]
      %i[start_date end_date].all? { |attribute| affiliation[attribute].nil? || dates[attribute].nil? || affiliation[attribute] == dates[attribute] } &&
        (starts.nil? || ends.nil? || starts <= ends)
    end

    def identical_dates?(affiliation, dates)
      affiliation.start_date == dates[:start_date] && affiliation.end_date == dates[:end_date]
    end

    def shared_dates(affiliation, dates)
      %i[start_date end_date].count { |attribute| affiliation[attribute] && affiliation[attribute] == dates[attribute] }
    end

    def records_another_row?(affiliation, codes)
      codes && affiliation.filemaker_codes.any? { |code| codes.include?(code) }
    end

    # Some prod rows still carry an old-app role title (Leader, Liaison, …), each a Facilitator.
    def same_title?(held, title)
      held.to_s.squish.casecmp?(title.to_s.squish) ||
        (title == Affiliation::FACILITATOR_TITLE && DataHealth::LegacyRoleAffiliations.legacy_title?(held))
    end

    def link(affiliation, row, label, title:, attributes:, codes:)
      return record(:already_imported, "#{label} → affiliation ##{affiliation.id}") if codes.nil? && affiliation.title.present?

      affiliation.filemaker_code = Affiliation.join_filemaker_codes(affiliation.filemaker_code, row.fm_id) if codes
      affiliation.title = title if affiliation.title.blank?
      affiliation.primary_contact = true if attributes[:primary_contact]
      fill_dates(affiliation, attributes)
      affiliation.updated_by_id ||= updated_by(row.data)
      return failed(affiliation, label) unless affiliation.save

      @affiliations.add(row.fm_id, affiliation.id) if codes
      record(:linked, "#{label} → affiliation ##{affiliation.id}")
      affiliation
    end

    # A blank date takes the archive's. The archive's status only ends an affiliation the
    # portal still holds open with no dates of its own to say otherwise.
    def fill_dates(affiliation, attributes)
      attributes.slice(:start_date, :end_date).each { |attribute, value| affiliation[attribute] ||= value }
      return unless attributes[:inactive] && !affiliation.inactive? && affiliation.end_date.nil?

      affiliation.inactive = true
      affiliation.inactive_supplied = true
    end

    def create(person, organization, row, label, title:, attributes:, code:)
      data = row.data
      affiliation = person.affiliations.build(
        organization:, title:, filemaker_code: code, **attributes,
        inactive_supplied: attributes[:inactive],
        created_at: parse_date(data["DateEntered"]), updated_at: modified_on(data),
        created_by_id: @staff.user_id_for(data["EnteredBy"]) || @import_user_id, updated_by_id: updated_by(data)
      )
      return failed(affiliation, label) unless affiliation.save

      @affiliations.add(code, affiliation.id) if code
      record(:created, "#{label} → affiliation ##{affiliation.id}#{" (#{title})" if title}")
      affiliation
    end

    def modified_on(data)
      parse_date(data["DateTimeModified"].presence || data["ModificationTimeStamp"]) || parse_date(data["DateEntered"])
    end

    def updated_by(data)
      @staff.user_id_for(data["ModifiedBy"]) || @import_user_id
    end

    # Each work address lands on the organization it belongs to — the one FileMaker filed it
    # under, else the card's organization, else the person's only one — and the person's
    # affiliations there that name no address yet point at it. The worksite FileMaker named
    # goes first, so it's the one they point at. With nowhere to put it, it stays with the
    # person as their own work address.
    def place_work_addresses(rolodex, people, organization, work, label)
      work.sort_by { |address| address.fm_id == rolodex.data["WorksiteAddrsID"] ? 0 : 1 }.each do |fm_address|
        attributes = @address_attributes.call(fm_address.data, organization: true)&.merge(filemaker_code: fm_address.fm_id)
        next unless attributes

        people.each do |person|
          target = organization_for(fm_address.data["OrgID"]) || organization || sole_organization(person)
          next keep_with_person(person, attributes, label) unless target

          address = organization_address(target, attributes, label)
          next failed(address, label) unless address.persisted?

          person.affiliations.where(organization: target, organization_address_id: nil).find_each do |affiliation|
            affiliation.update(organization_address: address) || failed(affiliation, label)
          end
        end
      end
    end

    def sole_organization(person)
      ids = person.affiliations.distinct.pluck(:organization_id)
      Organization.find_by(id: ids.first) if ids.one?
    end

    def organization_address(organization, attributes, label)
      held = FmAddressAttributes.held(organization.addresses, attributes)
      return organization.addresses.create(attributes.merge(primary: organization.addresses.where(primary: true).none?)) unless held

      add_code(held, attributes[:filemaker_code], label)
      held
    end

    def keep_with_person(person, attributes, label)
      held = FmAddressAttributes.held(person.addresses, attributes)
      return add_code(held, attributes[:filemaker_code], label) if held

      address = person.addresses.create(attributes.merge(primary: person.addresses.where(primary: true).none?))
      return failed(address, label) unless address.persisted?

      record(:created, "#{label} → work address ##{address.id} kept on person ##{person.id}, no organization to place it on")
    end

    # An address already on file takes the archive row's code rather than a copy.
    def add_code(address, code, label)
      address.update(filemaker_code: Address.join_filemaker_codes(address.filemaker_code, code)) || failed(address, label)
    end

    def organization_for(code)
      code = code.to_s.strip
      return if code.blank?

      ids = @organizations.ids(code)
      Organization.find_by(id: ids.first) if ids.any?
    end

    def failed(record, label)
      record(:failed, "#{label}: #{record.class.name} #{record.errors.full_messages.to_sentence.presence || "matches one already on file"}")
      false
    end

    def record(outcome, message)
      @results[outcome] << message
    end
  end
end
