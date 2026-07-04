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
    def self.call(organization:, city: nil, state: nil, street_address: nil, zip_code: nil, country: nil)
      new(organization:, city:, state:, street_address:, zip_code:, country:).call
    end

    def initialize(organization:, city: nil, state: nil, street_address: nil, zip_code: nil, country: nil)
      @organization = organization
      @city = city&.strip
      @state = state&.strip
      @street_address = street_address
      @zip_code = zip_code
      @country = country&.strip
    end

    def call
      return if @city.blank?

      existing = @organization.addresses.find_by(
        "LOWER(city) = ? AND LOWER(COALESCE(state, '')) = ?",
        @city.downcase, @state&.downcase.to_s
      )

      make_primary = @organization.addresses.active.where(primary: true).none?

      if existing
        existing.update!(
          street_address: @street_address,
          zip_code: @zip_code,
          primary: existing.primary? || make_primary,
          inactive: false
        )
        existing.update!(country: @country) if @country.present?
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
