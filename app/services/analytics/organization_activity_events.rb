module Analytics
  # The Ahoy events behind an organization's change log: the org record's own,
  # plus every event on its addresses — current ones by id, deleted ones through
  # the owner their delete snapshot names, so a merged-away address stays listed.
  class OrganizationActivityEvents
    def initialize(organization)
      @organization = organization
    end

    def relation
      Ahoy::Event.where(resource_type: "Organization", resource_id: @organization.id)
        .or(Ahoy::Event.where(resource_type: "Address", resource_id: address_ids))
    end

    private

    def address_ids
      @organization.addresses.pluck(:id) | deleted_address_ids
    end

    def deleted_address_ids
      Ahoy::Event.where(name: "destroy.address", resource_type: "Address")
        .where("JSON_UNQUOTE(JSON_EXTRACT(ahoy_events.properties, '$.attributes.addressable_type')) = 'Organization'")
        .where("CAST(JSON_EXTRACT(ahoy_events.properties, '$.attributes.addressable_id') AS UNSIGNED) = ?", @organization.id)
        .distinct.pluck(:resource_id)
    end
  end
end
