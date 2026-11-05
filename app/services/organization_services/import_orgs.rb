module OrganizationServices
  class ImportOrgs
    include FilemakerValues

    OUTCOMES = %i[created linked_project already_imported skipped failed].freeze
    BATCH_SIZE = 500
    TYPE_PATTERNS = {
      /501|non.?profit/i => "501c3/nonprofit",
      /for.?profit|\bLLC\b/i => "For-profit",
      /govt|government/i => "Government agency",
      /\Aother\z/i => Organization::ORGANIZATION_TYPE_OTHER
    }.freeze
    SCHOOL_PATTERN = /school/i

    attr_reader :results, :multi_org, :condensed, :suffixed, :retired,
                :unmatched_statuses, :unmatched_types, :unmatched_project_codes

    def unmatched_staff = @staff.unmatched

    def initialize(progress: nil)
      @progress = progress
      @results = OUTCOMES.index_with { [] }
      @multi_org = []
      @condensed = []
      @suffixed = []
      @retired = []
      @unmatched_statuses = Hash.new(0)
      @unmatched_types = Hash.new(0)
      @placed_by_org = Hash.new { |hash, key| hash[key] = [] }
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
      @unmatched_project_codes = project_codes.reject { |code| @codes.include?(code) }
      @condensed = @placed_by_org.select { |_id, codes| codes.size > 1 }
                                .map { |id, codes| "##{id} #{@org_by_id[id]&.name}: #{codes.join(', ')}" }
      self
    end

    private

    def load_indexes
      @codes = Set.new
      @holders = Hash.new { |hash, key| hash[key] = [] }
      @org_by_id = {}
      Organization.find_each do |organization|
        @org_by_id[organization.id] = organization
        organization.filemaker_codes.each do |code|
          @codes << code
          @holders[code] << organization
        end
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
      return record(:already_imported, "#{code} #{name}") if @codes.include?(code)

      note_retired(code, name)
      projects = @projects_by_org[code] || []
      targets = projects.flat_map { |project| @holders[project.fm_id] }.uniq
      return attach_to_targets(code, name, targets) if targets.any?

      create_org(code, name, data, projects)
    end

    def attach_to_targets(code, name, targets)
      failed = targets.reject do |organization|
        organization.filemaker_code = Organization.join_filemaker_codes(organization.filemaker_code, code)
        organization.save
      end
      unless failed.empty?
        return record(:failed, "#{code} #{name}: could not add the code to #{failed.map { |organization| "##{organization.id}" }.join(', ')}")
      end

      targets.each do |organization|
        @codes << code
        @holders[code] << organization unless @holders[code].include?(organization)
        @placed_by_org[organization.id] << code
      end
      if targets.size > 1
        @multi_org << "#{code} #{name} → #{targets.map { |organization| "##{organization.id} #{organization.name}" }.join('; ')}"
      end
      record(:linked_project, "#{code} #{name} → #{targets.map { |organization| "##{organization.id}" }.join(', ')}")
    end

    def create_org(code, name, data, projects)
      organization = Organization.new(name: unique_name(name, code))
      fill(organization, attributes(data))
      apply_status(organization, data["Status"])
      stamp(organization, data)
      organization.filemaker_code = Organization.join_filemaker_codes(code, *claimable_project_codes(projects))
      return failed(organization, "#{code} #{name}") unless organization.save

      index(organization)
      record(:created, "#{code} #{name} → ##{organization.id}")
    end

    def claimable_project_codes(projects)
      projects.one? ? [ projects.first.fm_id ] : []
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

      organization.organization_status = status
    end

    def fill(organization, attributes)
      attributes.each do |attribute, value|
        next if value.blank?
        next if attribute == :organization_type_other && organization.organization_type != Organization::ORGANIZATION_TYPE_OTHER

        organization[attribute] = value
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
      @org_by_id[organization.id] = organization
      organization.filemaker_codes.each do |code|
        @codes << code
        @holders[code] << organization unless @holders[code].include?(organization)
      end
    end

    def note_retired(code, name)
      return unless retired_record?(code) || name.match?(RETIRED_MARKER)

      @retired << "#{code} #{name}"
    end

    def project_codes
      @project_codes ||= @projects_by_org.values.flatten.map(&:fm_id)
    end

    def failed(organization, label)
      record(:failed, "#{label}: #{organization.errors.full_messages.to_sentence}")
      nil
    end

    def record(outcome, message)
      @results[outcome] << message
    end
  end
end
