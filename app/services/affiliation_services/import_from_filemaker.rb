module AffiliationServices
  # Turns the FileMaker archive's ties between people and organizations into affiliations
  # (ADR-0008), after the Rolodex and organizations passes have made both ends. Reads, in
  # order:
  #
  #   1. Personnel (FmPersonnel) — a person staffing a project's art program becomes a
  #      Facilitator affiliation, dated from when the row was entered to when the project
  #      closed, with a comment naming the role FileMaker gave. Only a Leader or Liaison is a
  #      primary contact — turned on for a Facilitator row the portal already had. It links
  #      an existing Facilitator row only for the same stretch (#same_stint), so separate
  #      stints stay separate. Each carries the row's PrsnlRecID as its filemaker_code.
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
  # dates, keeping its own where FileMaker disagrees (noted in #differences and as a
  # comment on the affiliation).
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
    LEGACY_LEADER_TITLE = "Leader"
    ROLE_COMMENT_TOPIC = "FileMaker import"
    # Stands in where a Personnel row names a project but no person.
    PLACEHOLDER_NAME = { first_name: "AWBW", last_name: "Placeholder" }.freeze
    SOURCES = { FmPersonnel => "Personnel", FmPeopleToOrganization => "People-to-organizations", FmRolodex => "Rolodex" }.freeze

    attr_reader :results, :differences, :statuses, :roles

    def unmatched_addresses = @address_attributes.unmatched

    def initialize(progress: nil, run: nil)
      @progress = progress
      @run = run
      @results = OUTCOMES.index_with { [] }
      @differences = []
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
      @unstaffed = []
      @read = 0

      each_batch(FmPersonnel.all) { |row| import_personnel(row) }
      each_batch(FmPeopleToOrganization.all) { |row| import_job(row) }
      addresses = FmRolodex.contact_index(FmAddress)
      phones = FmRolodex.contact_index(FmPhoneNumber)
      each_batch(FmRolodex.all) { |rolodex| import_rolodex(rolodex.preload_contacts(addresses:, phone_numbers: phones)) }
      in_batch(@unstaffed) { |row, organization, label| import_unstaffed(row, organization, label) }
      self
    end

    private

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

      people = @people.records(data["PersonID"])
      organization = organization_for(data["ProjectID"])
      return record(:skipped, "#{label}: project #{data["ProjectID"].presence || "(none)"} wasn't imported") unless organization
      return @unstaffed << [ row, organization, label ] if data["PersonID"].blank?
      return record(:skipped, "#{label}: person #{data["PersonID"]} wasn't imported") if people.empty?

      dates = personnel_dates(data, @projects[data["ProjectID"].to_s])
      role = data["Role"].to_s.squish
      attributes = dates.merge(primary_contact: primary_contact?(role))
      people.each do |person|
        affiliation = affiliate(person, organization, row, label, title: Affiliation::FACILITATOR_TITLE, attributes:, codes: @personnel_ids, dated: true)
        note_role(affiliation, row, role) if affiliation && role.present?
      end
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
    # and ends when its project closed. A status that isn't active ends it now, undated.
    def personnel_dates(data, project)
      status = data["Status"].to_s.squish
      active = ACTIVE_STATUSES.include?(status.downcase)
      @statuses["#{status.presence || "(blank)"} → #{active ? "active" : "ended"}"] += 1
      start_date = parse_date(data["DateEntered"])
      end_date = project && (parse_date(project.data["CloseDate"]) || parse_date(project.data["EndDate"]))
      end_date = nil if start_date && end_date && end_date < start_date
      { start_date:, end_date:, inactive: !active }
    end

    def import_job(row)
      data = row.data
      label = "#{row.fm_id} #{data["PersonID"]} at #{data["OrgID"]}"
      return record(:already_imported, label) if @affiliations.include?(row.fm_id)

      people = @people.records(data["PersonID"])
      organization = organization_for(data["OrgID"])
      return record(:skipped, "#{label}: person wasn't imported") if people.empty?
      return record(:skipped, "#{label}: organization wasn't imported") unless organization

      people.each { |person| affiliate(person, organization, row, label, title: clip(data["Title"].to_s.squish), attributes: {}, codes: @job_ids) }
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
      match = dated ? same_stint(candidates, attributes) : candidates.first
      match ||= existing.find { |affiliation| affiliation.title.blank? } if title.present? && codes.nil?
      return link(match, row, label, title:, attributes:, codes:) if match

      create(person, organization, row, label, title:, attributes:, code: codes && row.fm_id)
    end

    # A person can facilitate at one organization over several separate stretches, so a
    # Personnel row links only the affiliation recording the same one: the periods overlap,
    # reading a blank start as "since whenever" and a blank end as "still going" — except an
    # ended row with no end date, which reads as the moment it started, so it can't reach a
    # later stretch. Identical dates win, then the nearest start, then one with dates at all.
    def same_stint(candidates, dates)
      period = stint(dates[:start_date], dates[:end_date], dates[:inactive])
      candidates.select { |affiliation| overlap?(period, stint(affiliation.start_date, affiliation.end_date, affiliation.inactive?)) }
                .min_by { |affiliation| stint_rank(affiliation, dates) }
    end

    def stint(start_date, end_date, ended)
      [ start_date, end_date || (start_date if ended) ]
    end

    def overlap?((starts, ends), (other_starts, other_ends))
      (starts.nil? || other_ends.nil? || starts <= other_ends) && (other_starts.nil? || ends.nil? || other_starts <= ends)
    end

    def stint_rank(affiliation, dates)
      identical = affiliation.start_date == dates[:start_date] && affiliation.end_date == dates[:end_date]
      gap = (affiliation.start_date - dates[:start_date]).abs if affiliation.start_date && dates[:start_date]
      [ identical ? 0 : 1, gap || Float::INFINITY ]
    end

    def records_another_row?(affiliation, codes)
      codes && affiliation.filemaker_codes.any? { |code| codes.include?(code) }
    end

    # Some prod rows still carry the old app's "Leader" title, which is a Facilitator.
    def same_title?(held, title)
      held = held.to_s.squish
      held.casecmp?(title.to_s.squish) || (title == Affiliation::FACILITATOR_TITLE && held.casecmp?(LEGACY_LEADER_TITLE))
    end

    def link(affiliation, row, label, title:, attributes:, codes:)
      return record(:already_imported, "#{label} → affiliation ##{affiliation.id}") if codes.nil? && affiliation.title.present?

      affiliation.filemaker_code = Affiliation.join_filemaker_codes(affiliation.filemaker_code, row.fm_id) if codes
      affiliation.title = title if affiliation.title.blank?
      affiliation.primary_contact = true if attributes[:primary_contact]
      kept = fill_dates(affiliation, attributes)
      affiliation.updated_by_id ||= updated_by(row.data)
      return failed(affiliation, label) unless affiliation.save

      @affiliations.add(row.fm_id, affiliation.id) if codes
      note_differences(affiliation, row, label, kept) if kept.any?
      record(:linked, "#{label} → affiliation ##{affiliation.id}")
      affiliation
    end

    # A blank date takes the archive's. The archive's status only ends an affiliation the
    # portal still holds open with no dates of its own to say otherwise.
    def fill_dates(affiliation, attributes)
      kept = attributes.slice(:start_date, :end_date).filter_map do |attribute, value|
        next if value.nil? || affiliation[attribute] == value

        if affiliation[attribute].nil?
          affiliation[attribute] = value
          next
        end

        [ Affiliation.human_attribute_name(attribute), affiliation[attribute], value ]
      end
      if attributes[:inactive] && !affiliation.inactive? && affiliation.end_date.nil?
        affiliation.inactive = true
        affiliation.inactive_supplied = true
      end
      kept
    end

    def create(person, organization, row, label, title:, attributes:, code:)
      data = row.data
      entered = parse_date(data["DateEntered"])
      affiliation = person.affiliations.build(
        organization:, title:, filemaker_code: code, **attributes,
        inactive_supplied: attributes[:inactive],
        created_at: entered, updated_at: parse_date(data["DateTimeModified"].presence || data["ModificationTimeStamp"]) || entered,
        created_by_id: @staff.user_id_for(data["EnteredBy"]) || @import_user_id, updated_by_id: updated_by(data)
      )
      return failed(affiliation, label) unless affiliation.save

      @affiliations.add(code, affiliation.id) if code
      record(:created, "#{label} → affiliation ##{affiliation.id}#{" (#{title})" if title}")
      affiliation
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
        attributes = @address_attributes.call(fm_address.data, address_type: "work")
        next unless attributes

        people.each do |person|
          target = organization_for(fm_address.data["OrgID"]) || organization || sole_organization(person)
          next keep_with_person(person, attributes, label) unless target

          address = organization_address(target, attributes)
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

    def organization_address(organization, attributes)
      held = organization.addresses.find { |address| address_key(address.street_address, address.city) == address_key(attributes[:street_address], attributes[:city]) }
      return held if held

      organization.addresses.create(attributes.merge(primary: organization.addresses.where(primary: true).none?))
    end

    def keep_with_person(person, attributes, label)
      return if person.addresses.any? { |address| address_key(address.street_address, address.city) == address_key(attributes[:street_address], attributes[:city]) }

      address = person.addresses.create(attributes.merge(primary: person.addresses.where(primary: true).none?))
      return failed(address, label) unless address.persisted?

      record(:created, "#{label} → work address ##{address.id} kept on person ##{person.id}, no organization to place it on")
    end

    def address_key(street, city)
      [ AddressNormalizer.street(street), AddressNormalizer.city(city) ]
    end

    def organization_for(code)
      code = code.to_s.strip
      return if code.blank?

      ids = @organizations.ids(code)
      Organization.find_by(id: ids.first) if ids.any?
    end

    def note_differences(affiliation, row, label, kept)
      lines = kept.map { |field, portal, archive| "#{field}: kept “#{portal}”, FileMaker has “#{archive}”" }
      Comment.create!(commentable: affiliation,
                      body: "FileMaker #{SOURCES[row.class]} #{row.fm_id} differs from this affiliation:\n#{lines.join("\n")}")
      @differences << "#{label} → affiliation ##{affiliation.id}: #{lines.join('; ')}"
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
