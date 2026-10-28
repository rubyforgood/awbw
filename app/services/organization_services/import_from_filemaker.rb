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
  #   * skipped          — nameless rows, rows retired in FileMaker (RETIRED_RECORDS), and
  #                        merged projects with nowhere to fold into
  #   * failed           — the Organization didn't validate
  #
  # Fields fill blanks only. Where the portal already holds a different value it keeps its
  # own, noted in #differences and as a comment on the organization. Also carried:
  #   * the organization's addresses (fm_addresses by OrgID), its phones (fm_phone_numbers),
  #     and its email (fm_email_addresses) — each address and phone carrying its row's ID as
  #     its own filemaker_code
  #   * each project's City/State with its Locality, District, SPA and supervisorial
  #     district, onto the program's address in that city
  #   * a merged-away project's code, onto the program it merged into
  #   * an organization's FileMaker ParentID, as its parent's portal organization (ADR-0004),
  #     each listed in #nested
  #   * a retired duplicate organization (RETIRED_DUPLICATE_OF) — its code, blanks, addresses,
  #     phones, email and projects — onto the organization it duplicated
  #   * an agency's own Rolodex card: its code, website, mission and addresses (and its email,
  #     when the card names no contact person whose email it would be)
  #   * an organization's projects sharing a name (FilemakerNames.same_name_key), as one program
  #     carrying every code — a single program when they're all its projects
  #   * the organization a Rolodex card names, for someone staffing a project that wasn't
  #     imported, created by name when nothing answers to it
  #
  # A code counts only on an organization answering to the FileMaker name of some code it
  # carries (FilemakerNames) — a merged organization answers to every code it gathered. When
  # no organization carrying the code does, it stays where it is and the row lands on the
  # organization its name finds or a new one, which takes the code too; each is listed in
  # #code_mismatches and left as a comment on the organization that already carried it.
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
    # FileMaker kept no school flag of its own, so the word in its type field is the only thing
    # that says an organization is one. Independent of the type, as the index's filter is: a
    # school can be a government agency, a nonprofit, or none of the four.
    SCHOOL_PATTERN = /school/i
    TYPE_FIELDS = %i[organization_type organization_type_other].freeze
    COMMENT_SOURCES = { FmOrganization => "FileMaker organization", FmProject => "FileMaker project",
                        FmRolodex => "FileMaker Rolodex agency" }.freeze

    attr_reader :results, :differences, :unmatched_types, :unmatched_phone_types, :nested, :unplaced, :code_mismatches

    def unmatched_addresses = @address_attributes.unmatched
    def unmatched_staff = @staff.unmatched

    def initialize(fm_ids: nil, progress: nil, run: nil)
      @fm_ids = fm_ids.presence&.to_set
      @progress = progress
      @run = run
      @results = OUTCOMES.index_with { [] }
      @differences = []
      @nested = []
      @unplaced = []
      @code_mismatches = []
      @unmatched_types = Hash.new(0)
      @unmatched_phone_types = Hash.new(0)
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
      @names = FilemakerNames.new(projects:)
      @project_ids = @projects.keys.to_set
      @addresses = FmAddress.all.group_by { |address| address.data["OrgID"].to_s }
      @phones = FmPhoneNumber.all.group_by { |phone| phone.data["OrgID"].to_s }
      @emails = FmEmailAddress.all.group_by { |email| email.data["OrgID"].to_s }

      @wanted = wanted_codes(projects)
      projects = projects.select { |project| wanted?(project.fm_id) }
      retired, projects = projects.partition { |project| retired_record?(project.fm_id) }
      retired.each { |project| record(:skipped, "#{project.fm_id} #{project_name(project)}: retired in FileMaker") }
      merged, live = projects.partition { |project| merged_into(project) }
      by_organization = live.group_by { |project| project.data["OrgID"].to_s }
      @duplicates = []
      @mismatches = {}
      read = 0
      wanted_scope(FmOrganization.all).find_in_batches(batch_size: BATCH_SIZE) do |batch|
        import_batch(batch) { |organization| import_organization(organization, by_organization.delete(organization.fm_id) || []) }
        @progress&.call(read += batch.size)
      end
      import_batch(by_organization.values.flatten) { |project| import_projects(nil, [ project ]) }
      import_batch(@duplicates) { |fm_organization, projects| fold_duplicate(fm_organization, projects) }
      parents = wanted_scope(FmOrganization.where("JSON_UNQUOTE(JSON_EXTRACT(data, '$.ParentID')) NOT IN ('', 'null')"))
      import_batch(parents) { |child| nest_under_parent(child) }
      import_batch(merged) { |project| fold_merged(project) }
      import_batch(agency_cards.select { |rolodex| wanted?(rolodex.fm_id) }) { |rolodex| import_agency(rolodex) }
      import_batch(unplaced_staff_cards) { |rolodex| import_card_organization(rolodex) }
      import_batch(@mismatches.keys) { |code| note_mismatch(nil, code) }
      self
    end

    private

    # Each batch commits on its own, so a run that stops partway keeps what it finished.
    # Its activity events, tagged with the run, commit with it — UndoRolodexImport reads them.
    # Untouched, so an address added to an organization doesn't stamp it as edited now.
    # FM_IDS names the archive rows to read. An organization can't be imported apart from its
    # projects — one project makes it a single program, several make it an umbrella — so a named
    # organization brings its projects and a named project brings its organization.
    def wanted_codes(projects)
      return unless @fm_ids

      named = projects.select { |project| @fm_ids.include?(project.fm_id) }
      @fm_ids +
        named.map { |project| project.data["OrgID"].to_s } +
        projects.select { |project| @fm_ids.include?(project.data["OrgID"].to_s) }.map(&:fm_id)
    end

    def wanted?(code)
      @wanted.nil? || @wanted.include?(code.to_s)
    end

    def wanted_scope(scope)
      @wanted ? scope.where(fm_id: @wanted.to_a) : scope
    end

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
      name = organization_name(fm_organization)
      label = "#{fm_organization.fm_id} #{name}".squish
      if name.blank? || retired_record?(fm_organization.fm_id)
        return @duplicates << [ fm_organization, projects ] if duplicate_of(fm_organization.fm_id)

        record(:skipped, "#{label}: #{name.blank? ? "no name" : "retired in FileMaker"}")
        return import_projects(nil, projects)
      end

      umbrella = coded_as(fm_organization.fm_id, name) || named(fm_organization, name, @organization_ids)
      return import_single_program(fm_organization, coded_first(projects), umbrella, label) if one_program?(projects)

      umbrella ||= Organization.new(name: unique_name(name, fm_organization.fm_id))
      return unless note_mismatch(save(umbrella, fm_organization, label, organization_attributes(data)), fm_organization.fm_id)

      import_projects(umbrella, projects)
    end

    # Projects sharing a name are one program the old app split by audience.
    def one_program?(projects)
      return true if projects.one?

      keys = projects.map { |project| FilemakerNames.same_name_key(project_name(project)) }.uniq
      keys.one? && keys.first.present?
    end

    # A project whose code an organization already carries goes first, so its namesakes join it.
    def coded_first(projects)
      projects.sort_by { |project| @codes.include?(project.fm_id) ? 0 : 1 }
    end

    # One organization running one program is a single place, so it stays one portal
    # organization carrying every code — unless the portal already keeps them apart.
    def import_single_program(fm_organization, projects, umbrella, label)
      project, *namesakes = projects
      program = coded_as(project.fm_id, project_name(project)) || named(project, project_name(project), @project_ids)
      if umbrella && program && umbrella != program
        return unless note_mismatch(save(umbrella, fm_organization, label, organization_attributes(fm_organization.data)), fm_organization.fm_id)

        return import_projects(umbrella, projects)
      end

      organization = umbrella || program || Organization.new(name: unique_name(organization_name(fm_organization), project.fm_id))
      organization_side = organization_attributes(fm_organization.data)
      attributes = organization_side.merge(project_attributes(project.data)) { |_key, mine, theirs| mine.presence || theirs }
      attributes.merge!(organization_side.slice(*TYPE_FIELDS)) if organization_side[:organization_type]
      saved = save(organization, fm_organization, "#{label} + #{project.fm_id}", attributes, also: project)
      note_mismatch(saved, fm_organization.fm_id)
      note_mismatch(saved, project.fm_id)
      return unless saved

      namesakes.each do |namesake|
        name = project_name(namesake)
        note_mismatch(save(coded_as(namesake.fm_id, name) || saved, namesake, "#{namesake.fm_id} #{name}".squish,
                           project_attributes(namesake.data)), namesake.fm_id)
      end
    end

    def import_projects(umbrella, projects)
      programs = {}
      coded_first(projects).each do |project|
        name = project_name(project)
        label = "#{project.fm_id} #{name}".squish
        next record(:skipped, "#{label}: no name") if name.blank?

        key = FilemakerNames.same_name_key(name)
        program = coded_as(project.fm_id, name) || programs[key] || named(project, name, @project_ids) ||
                  Organization.new(name: unique_name(name, project.fm_id))
        nest(program, umbrella, label) if umbrella && program != umbrella
        saved = note_mismatch(save(program, project, label, project_attributes(project.data)), project.fm_id)
        programs[key] ||= saved if saved
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
      add_addresses(organization, @addresses.fetch(row.fm_id, []))
      rows.select { |source| source.is_a?(FmProject) }.each { |project| place_project(organization, project) }
      add_phones(organization, @phones.fetch(row.fm_id, []))
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

    # Read once every organization is in, so the one it duplicated is found by code.
    def fold_duplicate(fm_organization, projects)
      original_code = duplicate_of(fm_organization.fm_id)
      label = "#{fm_organization.fm_id} #{fm_organization.data["OrgName"].to_s.squish} (duplicate of #{original_code})"
      original = coded(original_code)
      unless original
        record(:skipped, "#{label}: #{original_code} wasn't imported")
        return import_projects(nil, projects)
      end
      return unless save(original, fm_organization, label, organization_attributes(fm_organization.data))

      import_projects(original, projects)
    end

    # Read once every organization is in, so both ends are found by code.
    def nest_under_parent(fm_organization)
      parent_code = fm_organization.data["ParentID"].to_s.strip
      label = "#{fm_organization.fm_id} #{organization_name(fm_organization)}".squish
      child = coded(fm_organization.fm_id)
      parent = coded(parent_code)
      return @nested << "#{label}: not nested — it or its parent #{parent_code} wasn't imported" unless child && parent
      return @nested << "#{label} → ##{child.id}: same organization as its parent #{parent_code}" if child == parent

      nest(child, parent, label)
      return unless child.parent_id_changed?
      return failed(child, label) unless child.save

      @nested << "#{label} → ##{child.id} under ##{parent.id} (#{parent_code})"
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
      organization = coded(rolodex.fm_id) || coded(data["OrgID"]) || (@name_matcher.call(name)&.organization if name)
      return record(:skipped, "#{label}: agency card with no organization named") if organization.nil? && name.blank?
      return record(:skipped, "#{label}: agency card naming #{data["OrgID"]}, retired in FileMaker") if organization.nil? && retired_record?(data["OrgID"])

      organization ||= Organization.new(name:)
      organization.filemaker_code = Organization.join_filemaker_codes(organization.filemaker_code, rolodex.fm_id)
      kept = fill(organization, website_url: clip(data["WebSite"]), mission_vision_values: clip(data["Mission"]))
      stamp(organization, data)
      add_addresses(organization, rolodex.addresses)
      add_phones(organization, rolodex.phone_numbers)
      fill_email(organization, [ data["EMail"] ]) unless names_a_person?(data)
      outcome = agency_outcome(organization)
      return failed(organization, label) unless organization.save

      @codes.add(rolodex.fm_id, organization.id)
      note_differences(organization, rolodex, label, kept) if kept.any?
      record(outcome, "#{label} → ##{organization.id} (agency card)")
    end

    # A Personnel row whose project wasn't imported (or names none) places its person at the
    # organization on their Rolodex card, so the one its typed name means is created when
    # nothing answers to it — the person staffed a program there.
    def unplaced_staff_cards
      unplaced = FmPersonnel.all.select do |row|
        (wanted?(row.fm_id) || wanted?(row.data["PersonID"])) && !@codes.include?(row.data["ProjectID"].to_s)
      end
      FmRolodex.where(fm_id: unplaced.map { |row| row.data["PersonID"].to_s }.compact_blank.uniq).order(:fm_id).to_a
    end

    def import_card_organization(rolodex)
      data = rolodex.data
      name = data["Organization"].to_s.squish
      return if name.blank? || retired_record?(data["OrgID"]) || coded(data["OrgID"]) || @name_matcher.call(name)

      label = "#{rolodex.fm_id} #{rolodex.name}".squish
      organization = Organization.create(name: clip(name), created_by_id: @import_user_id, updated_by_id: @import_user_id)
      return failed(organization, label) unless organization.persisted?

      record(:created, "#{label} → ##{organization.id} (#{organization.name}), named on the Rolodex card of someone staffing a project that wasn't imported")
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

    # Of the organizations carrying the code, the one FileMaker means.
    def coded(code)
      code = code.to_s.strip
      return if code.blank?

      ids = @codes.ids(code)
      return Organization.find_by(id: ids.first) if ids.size < 2

      @names.pick(Organization.where(id: ids).order(:id).to_a)
    end

    # The organization carrying the code that answers to its FileMaker name. When none does,
    # the code stays on them and the row finds or makes its own organization.
    def coded_as(code, name)
      carriers = Organization.where(id: @codes.ids(code)).order(:id).to_a
      return if carriers.empty?

      match = carriers.find { |organization| @names.answers?(organization) }
      @mismatches[code] = [ carriers, name ] unless match
      match
    end

    # Notes, once the row's own organization is saved, each organization that already carried
    # its code under another name — on the report and as a comment there.
    def note_mismatch(organization, code)
      carriers, name = @mismatches.delete(code)
      return organization unless carriers

      onto = organization ? "##{organization.id}" : "no organization — it failed to save"
      carriers.each do |carrier|
        Comment.create!(commentable: carrier,
                        body: "FileMaker #{code} is “#{name}”, which isn't this organization's name, so the import brought it " \
                              "in as #{onto}. This organization keeps #{code}.")
        @code_mismatches << "#{code} “#{name}”: kept on ##{carrier.id} “#{carrier.name}”, imported as #{onto}"
      end
      organization
    end

    # The organization by exact name. One already carrying another code from the same archive
    # table is a namesake of a different FileMaker record — unless they share a city.
    def named(row, name, table_ids)
      return if name.blank?

      organization = Organization.find_by(name:)
      return organization unless organization&.filemaker_codes&.any? { |code| table_ids.include?(code) }

      organization if shares_city?(organization, row)
    end

    def shares_city?(organization, row)
      cities = [ row.data["City"], *@addresses.fetch(row.fm_id, []).map { |address| address.data["AddrsCity"] } ]
               .filter_map { |city| AddressNormalizer.city(city).presence }
      cities.any? && organization.addresses.any? { |address| cities.include?(AddressNormalizer.city(address.city)) }
    end

    # Organization names are unique, so a FileMaker record whose name a namesake already
    # holds is told apart by its code.
    def unique_name(name, code)
      Organization.exists?(name:) ? clip("#{name} (#{code})") : name
    end

    def organization_name(fm_organization) = @names.organization_name(fm_organization)
    def project_name(project) = @names.project_name(project)

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

      school = value.match?(SCHOOL_PATTERN) ? { school: true } : {}
      type = ORGANIZATION_TYPE_PATTERNS.find { |pattern, _type| value.match?(pattern) }&.last
      return school.merge(organization_type: type) if type

      @unmatched_types[value] += 1
      school.merge(organization_type: Organization::ORGANIZATION_TYPE_OTHER, organization_type_other: clip(value))
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

    # An organization gathers addresses from every source, so one it already has takes the
    # archive row's code and the others are added; the first becomes its primary when it has none.
    def add_addresses(organization, fm_addresses)
      fm_addresses.each do |fm_address|
        attributes = @address_attributes.call(fm_address.data, organization: true)
        next if attributes.nil?

        held = FmAddressAttributes.held(organization.addresses, attributes)
        next held.filemaker_code = Address.join_filemaker_codes(held.filemaker_code, fm_address.fm_id) if held

        primary = organization.addresses.none? { |address| address.primary? && !address.marked_for_destruction? }
        organization.addresses.build(attributes.merge(primary:, filemaker_code: fm_address.fm_id))
      end
    end

    # FileMaker records a project's locality and districts, which the portal keeps on an
    # address — so they land on the program's address in the project's city (its primary
    # address when the project names no city), or on a new one holding just the city when
    # the program has no address there yet. A California locality places a project left
    # without a state; one with nowhere to land is listed in #unplaced.
    def place_project(organization, project)
      data = project.data
      city = clip(data["City"].to_s.squish)
      state = clip(data["State"].to_s.squish)
      geography = project_geography(data)
      address = if city.present?
        organization.addresses.find { |held| AddressNormalizer.city(held.city) == AddressNormalizer.city(city) }
      else
        organization.addresses.find(&:primary?) || organization.addresses.first
      end
      return fill_geography(address, geography) if address
      if city.blank?
        note_unplaced(project, "no city", geography) if geography.any?
        return
      end

      state = "CA" if state.blank? && Address::CALIFORNIA_LOCALITIES.include?(geography[:locality])
      return note_unplaced(project, "#{city}, no state", geography) if state.blank?

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

    def note_unplaced(project, missing, geography)
      found = geography.map { |attribute, value| "#{Address.human_attribute_name(attribute)} #{value}" }
      @unplaced << "#{project.fm_id} #{project_name(project)}: #{missing}#{" (#{found.join(", ")})" if found.any?}"
    end

    def district_number(value)
      value.to_s[/\d+/]&.to_i
    end

    # Each number lands on a phone record carrying its archive row's code — the one the
    # organization already holds for that number, else a new one, the archive's primary first.
    def add_phones(organization, fm_phones)
      fm_phones.sort_by { |phone| flag?(phone.data["Primacy"]) ? 0 : 1 }.each do |phone|
        number = clip(phone.data["PhoneNumber"].to_s.strip)
        next if number.blank?

        held = organization.contact_methods.find { |method| phone_key(method.value) == phone_key(number) }
        next held.filemaker_code = ContactMethod.join_filemaker_codes(held.filemaker_code, phone.fm_id) if held

        organization.contact_methods.build(
          kind: "phone", value: number, filemaker_code: phone.fm_id,
          contact_type: phone_type(phone.data["PhoneType"]),
          primary: organization.contact_methods.none?(&:primary?)
        )
      end
    end

    def phone_key(value)
      value.to_s.gsub(/\D/, "").presence
    end

    def phone_type(value)
      found = contact_type(value, allowed: ContactMethod::CONTACT_TYPES)
      @unmatched_phone_types[value.to_s.strip] += 1 if found.nil? && value.to_s.strip.present?
      found
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
