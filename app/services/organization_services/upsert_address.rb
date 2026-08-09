module OrganizationServices
  # Find-or-create an organization's work address from a registrant's submitted
  # agency address fields. When the org already has an address in the same
  # city/state, update it in place; otherwise add a new "work" address.
  #
  # Unlike a person's mailing address, an organization accumulates work addresses
  # from every registrant, so we never demote its existing primary: a registrant's
  # address becomes primary only when the org has none yet.
  #
  # Shared by the public registration flow and the admin org-linking actions so
  # both build the org address identically. Returns the Address, or nil when no
  # city was given (we key addresses on city, so a blank city means there is
  # nothing to save).
  class UpsertAddress
    def self.call(organization:, city: nil, state: nil, street_address: nil, zip_code: nil, country: nil, overwrite: true)
      new(organization:, city:, state:, street_address:, zip_code:, country:, overwrite:).call
    end

    def initialize(organization:, city: nil, state: nil, street_address: nil, zip_code: nil, country: nil, overwrite: true)
      @organization = organization
      @city = city&.strip
      @state = state&.strip.presence
      @street_address = street_address
      @zip_code = zip_code
      @country = country&.strip.presence
      @overwrite = overwrite
    end

    def call
      return if @city.blank?

      existing = AddressMatcher.call(@organization, city: @city, state: @state, street_address: @street_address)

      make_primary = @organization.addresses.active.where(primary: true).none?

      if existing
        # overwrite: false (admin linking) only fills blank fields, so a
        # discrepancy between the form and the org's saved address is kept and
        # surfaced by ProfileDiff instead of being silently replaced. State is
        # always fill-only (never flipped) so a street match can supply the state
        # we were missing without rewriting a state already on file.
        updates = { primary: existing.primary? || make_primary, inactive: false }
        updates[:state] = @state if @state.present? && existing.state.blank?
        updates[:street_address] = @street_address if @street_address.present? && (@overwrite || existing.street_address.blank?)
        updates[:zip_code] = @zip_code if @zip_code.present? && (@overwrite || existing.zip_code.blank?)
        updates[:country] = @country if @country.present? && (@overwrite || existing.country.blank?)
        existing.update!(updates)
        return existing
      end

      @organization.addresses.create!(
        street_address: @street_address,
        city: @city,
        state: @state,
        zip_code: @zip_code,
        country: @country,
        locality: "Unknown",
        address_type: "work",
        primary: make_primary
      )
    end
  end
end
