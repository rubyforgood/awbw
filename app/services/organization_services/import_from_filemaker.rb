module OrganizationServices
  # Turns the FileMaker archive's organizations (FmOrganization) and the art programs run at
  # them (FmProject) into portal organizations (ADR-0008). Runs after the Rolodex pass and
  # before AffiliationServices::ImportFromFilemaker, which finds what this creates by code.
  #
  # An app organization is usually a FileMaker project; the FileMaker organization above it
  # becomes its parent (ADR-0004). An organization with exactly one project is one place,
  # not two, so it stays one portal organization carrying both codes. Each archive row is
  # matched to an existing organization by any shared filemaker_code first, then by exact
  # name — but only to one carrying no code from that row's table yet, since a name taken
  # by another FileMaker record is a namesake, not a match. A match takes the row's code.
  #
  # Every row lands in one outcome bucket of #results:
  #   * created          — a new organization
  #   * linked           — an existing organization took the row's code and was filled
  #   * already_imported — an organization already carried the row's code
  #   * skipped          — nameless rows, and merged projects with nowhere to fold into
  #   * failed           — the Organization didn't validate
  #
  # Fields fill blanks only. Where the portal already holds a different value it keeps its
  # own, noted in #differences and as a comment on the organization. Also carried:
  #   * the organization's addresses (fm_addresses by OrgID), its phone onto its main
  #     address, and its email (fm_email_addresses)
  #   * each project's City/State with its Locality, District, SPA and supervisorial
  #     district, onto the program's address in that city
  #   * a merged-away project's code, onto the program it merged into
  #   * an agency's own Rolodex card: its website, mission and addresses (and its email,
  #     when the card names no contact person whose email it would be)
  class ImportFromFilemaker
    include FilemakerValues

    OUTCOMES = %i[created linked already_imported skipped failed].freeze
    BATCH_SIZE = 500
    # FileMaker's OrgType / AgencyType words onto Organization::ORGANIZATION_TYPES, first
    # match winning — so a value naming two types ("501c3/Nonprofit Government Agency"), as
    # FileMaker's multi-select stored them, takes the first. Any other word ("School",
    # "Grassroots") is Other, with the word kept as its description.
    ORGANIZATION_TYPE_PATTERNS = {
      /501|non.?profit/i => "501c3/nonprofit",
      /for.?profit|\bLLC\b/i => "For-profit",
      /govt|government/i => "Government agency",
      /\Aother\z/i => Organization::ORGANIZATION_TYPE_OTHER
    }.freeze
    TYPE_FIELDS = %i[organization_type organization_type_other].freeze
    COMMENT_SOURCES = { FmOrganization => "FileMaker organization", FmProject => "FileMaker project",
                        FmRolodex => "FileMaker Rolodex agency" }.freeze

    attr_reader :results, :differences, :unmatched_types

    def unmatched_addresses = @address_attributes.unmatched

    def initialize(progress: nil, run: nil)
      @progress = progress
      @run = run
      @results = OUTCOMES.index_with { [] }
      @differences = []
      @unmatched_types = Hash.new(0)
      @staff = StaffTranslation.new
      @import_user_id = Setting.import_user&.id
      @address_attributes = FmAddressAttributes.new
      @name_matcher = NameMatcher.new
    end

    def call
      @tracker = Ahoy::Tracker.new
      @codes = FilemakerCodeIndex.new(Organization)
      @organization_ids = FmOrganization.pluck(:fm_id).to_set
      projects = FmProject.all.to_a
      @projects = projects.index_by(&:fm_id)
      @project_ids = @projects.keys.to_set
      @addresses = FmAddress.all.group_by { |address| address.data["OrgID"].to_s }
      @phones = FmPhoneNumber.all.group_by { |phone| phone.data["OrgID"].to_s }
      @emails = FmEmailAddress.all.group_by { |email| email.data["OrgID"].to_s }

      merged, live = projects.partition { |project| merged_into(project) }
      by_organization = live.group_by { |project| project.data["OrgID"].to_s }
      read = 0
      FmOrganization.find_in_batches(batch_size: BATCH_SIZE) do |batch|
        import_batch(batch) { |organization| import_organization(organization, by_organization.delete(organization.fm_id) || []) }
        @progress&.call(read += batch.size)
      end
      import_batch(by_organization.values.flatten) { |project| import_projects(nil, [ project ]) }
      import_batch(merged) { |project| fold_merged(project) }
      import_batch(agency_cards) { |rolodex| import_agency(rolodex) }
      self
    end

    private

    # Each batch commits on its own, so a run that stops partway keeps what it finished.
    # Its activity events, tagged with the run, commit with it — UndoRolodexImport reads them.
    # Untouched, so an address added to an organization doesn't stamp it as edited now.
    def import_batch(rows, &import)
      ActiveRecord::Base.transaction(requires_new: true) do
        ActiveRecord::Base.no_touching do
          Analytics::LifecycleBuffer.tagging(@run ? { import_run: @run } : {}) { rows.each(&import) }
        end
        Analytics::LifecycleBuffer.flush_to(@tracker)
      end
    end

    def import_organization(fm_organization, projects)
      data = fm_organization.data
      name = clip(data["OrgName"].to_s.squish)
      label = "#{fm_organization.fm_id} #{name}".squish
      if name.blank?
        record(:skipped, "#{label}: no name")
        return import_projects(nil, projects)
      end

      umbrella = coded(fm_organization.fm_id) || named(name, @organization_ids)
      return import_single_program(fm_organization, projects.sole, umbrella, label) if projects.one?

      umbrella ||= Organization.new(name: unique_name(name, fm_organization.fm_id))
      return unless save(umbrella, fm_organization, label, organization_attributes(data))

      import_projects(umbrella, projects)
    end

    # One organization running one program is a single place, so it stays one portal
    # organization carrying both codes — unless the portal already keeps them apart.
    def import_single_program(fm_organization, project, umbrella, label)
      program = coded(project.fm_id) || named(project_name(project), @project_ids)
      if umbrella && program && umbrella != program
        return unless save(umbrella, fm_organization, label, organization_attributes(fm_organization.data))

        return import_projects(umbrella, [ project ])
      end

      organization = umbrella || program || Organization.new(name: unique_name(clip(fm_organization.data["OrgName"].to_s.squish), project.fm_id))
      organization_side = organization_attributes(fm_organization.data)
      attributes = organization_side.merge(project_attributes(project.data)) { |_key, mine, theirs| mine.presence || theirs }
      attributes.merge!(organization_side.slice(*TYPE_FIELDS)) if organization_side[:organization_type]
      save(organization, fm_organization, "#{label} + #{project.fm_id}", attributes, also: project)
    end

    def import_projects(umbrella, projects)
      projects.each do |project|
        name = project_name(project)
        label = "#{project.fm_id} #{name}".squish
        next record(:skipped, "#{label}: no name") if name.blank?

        program = coded(project.fm_id) || named(name, @project_ids) || Organization.new(name: unique_name(name, project.fm_id))
        nest(program, umbrella, label) if umbrella && program != umbrella
        save(program, project, label, project_attributes(project.data))
      end
    end

    # A program the portal already nests elsewhere stays where it is.
    def nest(program, umbrella, label)
      return program.parent = umbrella if program.parent_id.nil?
      return if program.parent_id == umbrella.id

      @differences << "#{label} → ##{program.id}: kept parent ##{program.parent_id}, FileMaker nests it under ##{umbrella.id}"
    end

    # Writes one archive row (and, for a single-program organization, its project too) onto
    # the organization: its code, blank fields, addresses, phone and email.
    def save(organization, row, label, attributes, also: nil)
      rows = [ row, also ].compact
      outcome = outcome_for(organization, rows)
      organization.filemaker_code = Organization.join_filemaker_codes(organization.filemaker_code, rows.map(&:fm_id))
      kept = fill(organization, attributes)
      stamp(organization, row.data)
      add_addresses(organization, @addresses.fetch(row.fm_id, []).map(&:data))
      rows.select { |source| source.is_a?(FmProject) }.each { |project| place_project(organization, project.data) }
      kept += add_phones(organization, @phones.fetch(row.fm_id, []).map(&:data))
      fill_email(organization, @emails.fetch(row.fm_id, []).map { |email| email.data["EmailAddress"] })
      return failed(organization, label) unless organization.save

      rows.each { |source| @codes.add(source.fm_id, organization.id) }
      note_differences(organization, row, label, kept) if kept.any?
      record(outcome, "#{label} → ##{organization.id}")
      organization
    end

    def outcome_for(organization, rows)
      return :created if organization.new_record?

      rows.all? { |row| organization.filemaker_codes.include?(row.fm_id) } ? :already_imported : :linked
    end

    # FileMaker kept a merged-away project's row, pointing at the one it merged into, so its
    # code joins that program and the records still naming it find their way there.
    def fold_merged(project)
      label = "#{project.fm_id} #{project_name(project)}".squish
      survivor = merged_into(project)
      program = coded(survivor.fm_id)
      own = coded(project.fm_id)
      return record(:skipped, "#{label}: merged into #{survivor.fm_id}, which wasn't imported") unless program
      return record(:already_imported, "#{label} → ##{program.id}") if own == program
      if own
        return record(:skipped, "#{label}: merged into #{survivor.fm_id} (##{program.id}) in FileMaker but still its own organization ##{own.id} — merge them by hand")
      end

      program.filemaker_code = Organization.join_filemaker_codes(program.filemaker_code, project.fm_id)
      return failed(program, label) unless program.save

      @codes.add(project.fm_id, program.id)
      record(:linked, "#{label} → ##{program.id} (merged into #{survivor.fm_id})")
    end

    # The project a merged-away one ended up in, following a chain of merges to its end.
    def merged_into(project)
      seen = Set[project.fm_id]
      survivor = nil
      while (next_id = (survivor || project).data["MergerWithID"].to_s.strip.presence) && seen.add?(next_id)
        break unless @projects[next_id]

        survivor = @projects[next_id]
      end
      survivor
    end

    # An agency's own Rolodex card describes the agency: it fills the organization its OrgID
    # names, or the one its name means, which is created when nothing answers to it.
    def import_agency(rolodex)
      data = rolodex.data
      name = clip(data["Organization"].to_s.squish)
      label = "#{rolodex.fm_id} #{name}".squish
      organization = coded(data["OrgID"]) || (@name_matcher.call(name)&.organization if name)
      return record(:skipped, "#{label}: agency card with no organization named") if organization.nil? && name.blank?

      organization ||= Organization.new(name:)
      kept = fill(organization, website_url: clip(data["WebSite"]), mission_vision_values: clip(data["Mission"]))
      stamp(organization, data)
      add_addresses(organization, rolodex.addresses.map(&:data))
      kept += add_phones(organization, rolodex.phone_numbers.map(&:data))
      fill_email(organization, [ data["EMail"] ]) unless names_a_person?(data)
      outcome = agency_outcome(organization)
      return failed(organization, label) unless organization.save

      note_differences(organization, rolodex, label, kept) if kept.any?
      record(outcome, "#{label} → ##{organization.id} (agency card)")
    end

    def agency_outcome(organization)
      return :created if organization.new_record?

      organization.changed_for_autosave? ? :linked : :already_imported
    end

    def agency_cards
      FmRolodex.agency_cards.order(:fm_id).select(&:agency?)
               .reject { |rolodex| flag?(rolodex.data["Delete"]) }
    end

    # A card naming a contact person carries that person's email, not the agency's.
    def names_a_person?(data)
      data["FirstName"].present? && data["LastName"].present?
    end

    def coded(code)
      code = code.to_s.strip
      return if code.blank?

      ids = @codes.ids(code)
      Organization.find_by(id: ids.first) if ids.any?
    end

    # The organization by exact name, unless it already carries another code from the same
    # archive table — then it's a namesake of a different FileMaker record.
    def named(name, table_ids)
      return if name.blank?

      organization = Organization.find_by(name:)
      organization unless organization&.filemaker_codes&.any? { |code| table_ids.include?(code) }
    end

    # Organization names are unique, so a FileMaker record whose name a namesake already
    # holds is told apart by its code.
    def unique_name(name, code)
      Organization.exists?(name:) ? clip("#{name} (#{code})") : name
    end

    def project_name(project)
      clip(project.data["ProjectName"].to_s.squish)
    end

    def organization_attributes(data)
      {
        website_url: clip(data["Website"]),
        description: data["Description"].to_s.strip.presence,
        mission_vision_values: clip(data["Mission"]),
        **organization_type(data["OrgType"]),
        **archive_timestamps(data["CreationDate"], data["ModificationDateTime"])
      }
    end

    def project_attributes(data)
      {
        description: data["Description"].to_s.strip.presence,
        **organization_type(data["AgencyType"]),
        **archive_timestamps(data["DateEntered"], data["DateTimeModified"])
      }
    end

    # The archive's own dates, so a created organization dates from when FileMaker first
    # knew it. Only a new record takes them; fill passes them over on an existing one.
    def archive_timestamps(entered, modified)
      entered = parse_date(entered)
      { created_at: entered, updated_at: parse_date(modified) || entered }
    end

    def organization_type(value)
      value = value.to_s.squish
      return {} if value.blank?

      type = ORGANIZATION_TYPE_PATTERNS.find { |pattern, _type| value.match?(pattern) }&.last
      return { organization_type: type } if type

      @unmatched_types[value] += 1
      { organization_type: Organization::ORGANIZATION_TYPE_OTHER, organization_type_other: clip(value) }
    end

    # Staff edited both systems, so neither side is newer by rule: a blank takes the
    # archive's value, and a disagreement keeps the portal's and is returned as
    # [ label, portal value, archive value ] to note.
    def fill(organization, attributes)
      timestamps, fields = attributes.partition { |attribute, _value| %i[created_at updated_at].include?(attribute) }
      timestamps.each { |attribute, value| organization[attribute] = value if organization.new_record? && value }
      fields.filter_map do |attribute, value|
        next if value.blank?
        # The description only belongs to an Other type, which the type just settled.
        next if attribute == :organization_type_other && organization.organization_type != Organization::ORGANIZATION_TYPE_OTHER

        if organization[attribute].blank?
          organization[attribute] = value
          next
        end
        next if organization[attribute].to_s.squish.casecmp?(value.to_s.squish)

        [ Organization.human_attribute_name(attribute), organization[attribute].to_s.truncate(80), value.to_s.truncate(80) ]
      end
    end

    # The staff FileMaker recorded as entering and last changing the row, or the settings'
    # import user. An existing organization keeps any stamps it already has.
    def stamp(organization, data)
      organization.created_by_id ||= @staff.user_id_for(data["CreatedBy"].presence || data["EnteredBy"]) || @import_user_id
      organization.updated_by_id ||= @staff.user_id_for(data["ModifiedBy"]) || @import_user_id
    end

    # An organization gathers addresses from every source, so it keeps the ones it has and
    # takes the archive's others; the first becomes its primary when it has none.
    def add_addresses(organization, rows)
      rows.each do |fields|
        attributes = @address_attributes.call(fields, address_type: "work")
        next if attributes.nil? || held_address(organization, attributes)

        primary = organization.addresses.none? { |address| address.primary? && !address.marked_for_destruction? }
        organization.addresses.build(attributes.merge(primary:))
      end
    end

    def held_address(organization, attributes)
      key = address_key(attributes[:street_address], attributes[:city])
      organization.addresses.find { |address| address_key(address.street_address, address.city) == key }
    end

    def address_key(street, city)
      [ AddressNormalizer.street(street), AddressNormalizer.city(city) ]
    end

    # FileMaker records a project's locality and districts, which the portal keeps on an
    # address — so they land on the program's address in the project's city, or on a new
    # one holding just the city when the program has no address there yet.
    def place_project(organization, data)
      city = clip(data["City"].to_s.squish)
      state = clip(data["State"].to_s.squish)
      return if city.blank?

      geography = project_geography(data)
      address = organization.addresses.find { |held| AddressNormalizer.city(held.city) == AddressNormalizer.city(city) }
      return fill_geography(address, geography) if address
      return if state.blank?

      primary = organization.addresses.none?(&:primary?)
      place = @address_attributes.place(city:, state:, county: geography[:county])
      organization.addresses.build(place.merge(geography.compact, address_type: "work", primary:))
    end

    def project_geography(data)
      {
        locality: Address::LOCALITIES.find { |locality| locality.casecmp?(data["Locality"].to_s.squish) },
        county: clip(data["County"].to_s.squish),
        district: clip(data["District"].to_s.squish),
        la_service_planning_area: district_number(data["SPA"]),
        la_supervisorial_district: district_number(data["LASupervisorialDistrict"])
      }.compact_blank
    end

    # A locality worked out from the address's parts is a guess the project's own answer
    # replaces when the guess was Unknown.
    def fill_geography(address, geography)
      geography.each do |attribute, value|
        current = address[attribute]
        address[attribute] = value if current.blank? || (attribute == :locality && current == Address::UNKNOWN_LOCALITY)
      end
    end

    def district_number(value)
      value.to_s[/\d+/]&.to_i
    end

    # The portal keeps an organization's phone on its addresses, so each number the archive
    # has that no address holds yet goes onto one without a phone, the primary first. One
    # with nowhere left to go is returned as a difference to note.
    def add_phones(organization, rows)
      held = organization.addresses.filter_map { |address| phone_key(address.phone) }
      numbers = rows.sort_by { |fields| flag?(fields["Primacy"]) ? 0 : 1 }
                    .filter_map { |fields| clip(fields["PhoneNumber"].to_s.strip) }
                    .uniq { |number| phone_key(number) }.reject { |number| held.include?(phone_key(number)) }
      numbers.filter_map do |number|
        address = organization.addresses.sort_by { |held_address| held_address.primary? ? 0 : 1 }.find { |held_address| held_address.phone.blank? }
        if address
          address.phone = number
          next
        end

        [ "Phone", organization.addresses.filter_map(&:phone).to_sentence.presence || "no address to hold it", number ]
      end
    end

    def phone_key(value)
      value.to_s.gsub(/\D/, "").presence
    end

    def fill_email(organization, values)
      organization.email = values.flat_map { |value| email_addresses(value) }.first if organization.email.blank?
    end

    def note_differences(organization, row, label, kept)
      lines = kept.map { |field, portal, archive| "#{field}: kept “#{portal}”, FileMaker has “#{archive}”" }
      Comment.create!(commentable: organization,
                      body: "#{COMMENT_SOURCES[row.class]} #{row.fm_id} differs from this organization:\n#{lines.join("\n")}")
      @differences << "#{label} → ##{organization.id}: #{lines.join('; ')}"
    end

    def failed(organization, label)
      record(:failed, "#{label}: #{"##{organization.id} " if organization.persisted?}#{organization.errors.full_messages.to_sentence}")
      nil
    end

    def record(outcome, message)
      @results[outcome] << message
    end
  end
end
