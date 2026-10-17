module ResourceServices
  # Links resources to an organization from the legacy free-text `agency` name:
  # an organization with exactly that name (case-insensitive) when one exists,
  # otherwise a new one. Idempotent — only touches resources with no organization.
  #
  # New organizations get status "Unknown" because Organization requires one, and
  # status is legacy and no longer consulted (ADR-0003 D4).
  class ResolveOrganizations
    NEW_ORGANIZATION_STATUS = "Unknown".freeze

    Result = Data.define(:linked, :created)

    def self.unresolved
      Resource.where.not(agency: [ nil, "" ]).where(organization_id: nil)
    end

    # `log` receives one line per resource, for the rake task's preview.
    def initialize(dry_run: false, log: nil)
      @dry_run = dry_run
      @log = log
    end

    def call
      status = OrganizationStatus.find_by(name: NEW_ORGANIZATION_STATUS)
      raise "OrganizationStatus #{NEW_ORGANIZATION_STATUS.inspect} is required to create organizations" if !@dry_run && status.nil?

      linked = created = 0
      created_by_name = {}

      ActiveRecord::Base.transaction do
        self.class.unresolved.find_each do |resource|
          name = resource.agency.strip
          next if name.blank?

          key = name.downcase
          if (organization = Organization.find_by(name: name))
            @log&.call("  = resource ##{resource.id}: link existing org ##{organization.id} #{name.inspect}")
          elsif created_by_name.key?(key)
            organization = created_by_name[key]
            @log&.call("  = resource ##{resource.id}: link org created earlier this run #{name.inspect}")
          else
            organization = @dry_run ? nil : Organization.create!(name: name, organization_status: status)
            created_by_name[key] = organization
            created += 1
            @log&.call("  + resource ##{resource.id}: create + link org #{name.inspect}")
          end
          linked += 1

          resource.update_attribute(:organization_id, organization.id) if organization
        end

        raise ActiveRecord::Rollback if @dry_run
      end

      Result.new(linked:, created:)
    end
  end
end
