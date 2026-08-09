module OrganizationServices
  # Find-or-create an organization's work address from a registrant's submitted
  # agency address fields. When AddressMatcher recognizes one of the org's
  # addresses as the same place, update it in place; otherwise add a new "work"
  # address.
  #
  # Unlike a person's mailing address, an organization accumulates work addresses
  # from every registrant, so we never demote its existing primary: a registrant's
  # address becomes primary only when the org has none yet.
  #
  # Shared by the public registration flow and the admin org-linking actions so
  # both build the org address identically.
  class UpsertAddress
    # address: the Address the submission was saved to — nil when no city was
    # given (we key addresses on city, so a blank city means nothing to save).
    # created: the submission added a new address rather than updating one.
    # filled: labels of the fields this call actually changed on an existing
    # address, so a caller can report what was saved instead of assuming.
    Result = Struct.new(:address, :created, :filled, keyword_init: true)

    FIELD_LABELS = {
      "street_address" => "street",
      "city" => "city",
      "state" => "state",
      "zip_code" => "ZIP",
      "country" => "country"
    }.freeze

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
      return Result.new(address: nil, created: false, filled: []) if @city.blank?

      existing = AddressMatcher.call(
        @organization, city: @city, state: @state, street_address: @street_address, zip_code: @zip_code
      )
      make_primary = @organization.addresses.active.where(primary: true).none?

      return Result.new(address: create_address(make_primary), created: true, filled: []) unless existing

      existing.assign_attributes(field_updates(existing))
      # Read the labels off `changed` rather than off what we assigned, so a
      # resubmission of values already on file isn't reported as saved.
      filled = existing.changed.filter_map { |attribute| FIELD_LABELS[attribute] }
      existing.primary = true if make_primary
      existing.inactive = false
      existing.save!

      Result.new(address: existing, created: false, filled: filled)
    end

    private

    # overwrite: false (admin linking) only fills blank fields, so a discrepancy
    # between the form and the org's saved address is kept and surfaced by
    # ProfileDiff instead of being silently replaced. City and state are always
    # fill-only (never flipped) so a street/ZIP match can supply what we were
    # missing without rewriting what's already on file.
    def field_updates(existing)
      updates = {}
      updates[:city] = @city if existing.city.blank?
      updates[:state] = @state if @state.present? && existing.state.blank?
      updates[:street_address] = @street_address if @street_address.present? && (@overwrite || existing.street_address.blank?)
      updates[:zip_code] = @zip_code if @zip_code.present? && (@overwrite || existing.zip_code.blank?)
      updates[:country] = @country if @country.present? && (@overwrite || existing.country.blank?)
      updates
    end

    def create_address(make_primary)
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
