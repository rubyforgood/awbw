module AffiliationServices
  # Every active-or-pending affiliation a person holds at an organization takes the
  # address their submission gave, whatever its title (the latest answer wins; the
  # prior one stays in the Ahoy audit trail). Ended ones are history and keep theirs.
  # Returns an OrganizationServices::AutofillChange per affiliation it re-pointed.
  class PointAtAddress
    # repoint: false when the address is a fallback (the org's sole address) rather
    # than one the person submitted — it then only fills a blank.
    def self.call(person:, organization:, address:, repoint: true)
      new(person:, organization:, address:, repoint:).call
    end

    def initialize(person:, organization:, address:, repoint: true)
      @person = person
      @organization = organization
      @address = address
      @repoint = repoint
    end

    def call
      return [] unless @address

      affiliations = @person.affiliations.active_or_pending.where(organization: @organization)
      targets = affiliations.where(organization_address_id: nil)
      targets = targets.or(affiliations.where.not(organization_address_id: @address.id)) if @repoint
      targets.includes(:organization_address).map do |affiliation|
        previous = affiliation.organization_address
        affiliation.update!(organization_address: @address)
        OrganizationServices::AutofillChange.new(
          field: "affiliation_#{affiliation.id}_address", label: "#{affiliation.title} affiliation address",
          value: @address.name.squish, previous_value: previous&.name&.squish
        )
      end
    end
  end
end
