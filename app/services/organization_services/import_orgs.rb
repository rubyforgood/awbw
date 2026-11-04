module OrganizationServices
  class ImportOrgs
    include FilemakerValues

    OUTCOMES = %i[created linked_name linked_project already_imported skipped failed].freeze
    BATCH_SIZE = 500
    ORG_CODE = /\AORG\d+\z/
    TYPE_PATTERNS = {
      /501|non.?profit/i => "501c3/nonprofit",
      /for.?profit|\bLLC\b/i => "For-profit",
      /govt|government/i => "Government agency",
      /\Aother\z/i => Organization::ORGANIZATION_TYPE_OTHER
    }.freeze
    SCHOOL_PATTERN = /school/i

    attr_reader :results, :differences, :status_disagreements, :conflicts,
                :multi_project_only, :withheld_codes, :suffixed, :retired,
                :unmatched_statuses, :unmatched_types, :unmatched_project_codes

    def unmatched_staff = @staff.unmatched

    def initialize(progress: nil)
      @progress = progress
      @results = OUTCOMES.index_with { [] }
      @differences = []
      @status_disagreements = []
      @conflicts = []
      @multi_project_only = []
      @withheld_codes = []
      @suffixed = []
      @retired = []
      @unmatched_statuses = Hash.new(0)
      @unmatched_types = Hash.new(0)
    end

    def call
      load_indexes
      read = 0
      FmOrganization.order(:fm_id).pluck(:id).each_slice(BATCH_SIZE) do |ids|
        ActiveRecord::Base.transaction(requires_new: true) do
          FmOrganization.where(id: ids).order(:fm_id).each { |row| import_row(row) }
        end
        read += ids.size
        @progress&.call(read)
      end
      @unmatched_project_codes = project_codes.reject { |code| @org_by_code.key?(code) }
      self
    end

    private

    def load_indexes
      @orgs_by_name_key = Hash.new { |hash, key| hash[key] = [] }
      @org_by_code = {}
      Organization.includes(:organization_status).find_each do |organization|
        @orgs_by_name_key[FilemakerNames.same_name_key(organization.name)] << organization
        organization.filemaker_codes.each { |code| @org_by_code[code] = organization }
      end
      @projects_by_org = FmProject.all.group_by { |project| project.data["OrgID"].to_s }
      @statuses = OrganizationStatus.all.index_by { |status| status.name.downcase }
      @staff = StaffTranslation.new
      @import_user_id = Setting.import_user&.id
    end

    def import_row(fm_organization)
      data = fm_organization.data
      code = fm_organization.fm_id
      name = clip(data["OrgName"].to_s.squish)
      return record(:skipped, "#{code}: no name") if name.blank?

      if (organization = @org_by_code[code])
        return record(:already_imported, "#{code} #{name} → ##{organization.id}")
      end

      projects = @projects_by_org[code] || []
      organization, outcome = find_match(name, projects)
      if organization.nil?
        organization = Organization.new(name: unique_name(name, code))
        outcome = :created
      end

      kept = fill(organization, attributes(data))
      apply_status(organization, data["Status"])
      stamp(organization, data)
      organization.filemaker_code = Organization.join_filemaker_codes(
        organization.filemaker_code, code, *claimable_project_codes(projects)
      )
      note_retired(code, name)
      return failed(organization, "#{code} #{name}") unless organization.save

      index(organization)
      note_conflicts(organization, code, name, projects, outcome)
      note_differences(organization, code, name, kept) if kept.any?
      record(outcome, "#{code} #{name} → ##{organization.id}")
    end

    def find_match(name, projects)
      organization = @orgs_by_name_key[FilemakerNames.same_name_key(name)].find { |candidate| uncoded?(candidate) }
      return [ organization, :linked_name ] if organization

      project = projects.first if projects.one?
      organization = project && @org_by_code[project.fm_id]
      return [ organization, :linked_project ] if organization && uncoded?(organization)

      [ nil, nil ]
    end

    def uncoded?(organization)
      organization.filemaker_codes.none? { |code| code.match?(ORG_CODE) }
    end

    def claimable_project_codes(projects)
      return [] unless projects.one?

      code = projects.first.fm_id
      @org_by_code.key?(code) ? [] : [ code ]
    end

    def attributes(data)
      {
        website_url: clip(data["Website"]),
        description: data["Description"].to_s.strip.presence,
        mission_vision_values: data["Mission"].to_s.strip.presence,
        **organization_type(data["OrgType"]),
        **archive_timestamps(data)
      }
    end

    def archive_timestamps(data)
      created = parse_date(data["CreationDate"])
      { created_at: created, updated_at: parse_date(data["ModificationDateTime"]) || created }
    end

    def organization_type(value)
      value = value.to_s.squish
      return {} if value.blank?

      school = value.match?(SCHOOL_PATTERN) ? { school: true } : {}
      type = TYPE_PATTERNS.find { |pattern, _type| value.match?(pattern) }&.last
      return school.merge(organization_type: type) if type

      @unmatched_types[value] += 1
      school.merge(organization_type: Organization::ORGANIZATION_TYPE_OTHER, organization_type_other: clip(value))
    end

    def apply_status(organization, value)
      name = value.to_s.strip
      return if name.blank?

      status = @statuses[name.downcase]
      if status.nil?
        @unmatched_statuses[name] += 1
        return
      end

      current = organization.organization_status
      if current.nil?
        organization.organization_status = status
      elsif current.id != status.id
        @status_disagreements << "#{organization.name}: portal #{current.name}, FileMaker #{name}"
      end
    end

    def fill(organization, attributes)
      timestamps, fields = attributes.partition { |attribute, _value| %i[created_at updated_at].include?(attribute) }
      timestamps.each { |attribute, value| organization[attribute] = value if organization.new_record? && value }
      fields.filter_map do |attribute, value|
        next if value.blank?
        next if attribute == :organization_type_other && organization.organization_type != Organization::ORGANIZATION_TYPE_OTHER

        if organization[attribute].blank?
          organization[attribute] = value
          next
        end
        next if organization[attribute].to_s.squish.casecmp?(value.to_s.squish)

        [ Organization.human_attribute_name(attribute), organization[attribute].to_s.truncate(80), value.to_s.truncate(80) ]
      end
    end

    def stamp(organization, data)
      organization.created_by_id ||= @staff.user_id_for(data["CreatedBy"]) || @import_user_id
      organization.updated_by_id ||= @staff.user_id_for(data["ModifiedBy"]) || @import_user_id
    end

    def unique_name(name, code)
      return name unless Organization.exists?(name:)

      final = clip("#{name} (#{code})")
      @suffixed << "#{code} #{name} → #{final}"
      final
    end

    def index(organization)
      key = FilemakerNames.same_name_key(organization.name)
      list = @orgs_by_name_key[key]
      list << organization unless list.include?(organization)
      organization.filemaker_codes.each { |code| @org_by_code[code] = organization }
    end

    def note_conflicts(organization, code, name, projects, outcome)
      held = projects.filter_map do |project|
        holder = @org_by_code[project.fm_id]
        [ project.fm_id, holder ] if holder && holder != organization
      end
      return if held.empty?

      held.each do |project_code, holder|
        @withheld_codes << "#{project_code} (row #{code} #{name}): already on ##{holder.id} #{holder.name}"
      end
      where = held.map { |project_code, holder| "#{project_code} ##{holder.id} #{holder.name}" }.join("; ")

      if outcome == :linked_name
        @conflicts << "#{code} #{name} → ##{organization.id}; project codes sit on #{where}"
      elsif projects.size > 1
        @multi_project_only << "#{code} #{name} → ##{organization.id}; project codes sit on #{where}"
      end
    end

    def note_retired(code, name)
      return unless retired_record?(code) || name.match?(RETIRED_MARKER)

      @retired << "#{code} #{name}"
    end

    def note_differences(organization, code, name, kept)
      lines = kept.map { |field, portal, archive| "#{field}: kept “#{portal}”, FileMaker has “#{archive}”" }
      @differences << "#{code} #{name} → ##{organization.id}: #{lines.join('; ')}"
    end

    def project_codes
      @project_codes ||= @projects_by_org.values.flatten.map(&:fm_id)
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
