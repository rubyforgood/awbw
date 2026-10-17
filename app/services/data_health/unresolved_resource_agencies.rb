module DataHealth
  # Resources still credited by the legacy free-text `agency` name, with no
  # organization linked. The `agency` column can be dropped once this is empty.
  class UnresolvedResourceAgencies < Check
    def title = "Resources with an agency name but no organization"

    def explanation
      "These still name their organization as free text. Linking matches each name to an " \
      "organization with exactly that name, and creates one when none exists."
    end

    def scope = ResourceServices::ResolveOrganizations.unresolved

    def repairable? = OrganizationStatus.exists?(name: ResourceServices::ResolveOrganizations::NEW_ORGANIZATION_STATUS)

    def repair_label = "Link organizations"

    def repaired_message(number)
      "Linked #{number} #{'resource'.pluralize(number)} to an organization."
    end

    def repair!
      ResourceServices::ResolveOrganizations.new.call.linked
    end

    def describe(resource)
      "#{resource.title} — “#{resource.agency.strip}”"
    end

    def path_for(resource) = resource_path(resource)
  end
end
