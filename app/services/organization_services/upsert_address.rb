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
  # both build the org address identically. A registrant's optional answers are
  # tolerated: a skipped street/ZIP is stored blank, and a submission with no
  # state saves no new address rather than failing the registration.
  class UpsertAddress
    # address: the Address the submission was saved to — nil when the submission
    # couldn't be stored (see storable? for what a new address needs).
    # created: the submission added a new address rather than updating one.
    # filled: labels of the fields this call actually changed on an existing
    # address, so a caller can report what was saved instead of assuming.
    Result = Struct.new(:address, :created, :filled, keyword_init: true) do
      # What this call actually wrote, named by city so an admin knows which work
      # address moved. Nil when nothing was saved or nothing changed — a caller
      # reporting the save must not claim more than happened.
      def saved_label
        return if address.nil?
        return "work address in #{address.city}" if created
        return if filled.empty?

        "#{filled.to_sentence} on the #{address.city} work address"
      end
    end

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
      return nothing_saved if @city.blank?

      existing = AddressMatcher.call(
        @organization, city: @city, state: @state, street_address: @street_address, zip_code: @zip_code
      )
      return nothing_saved if existing.nil? && !storable?

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

    # An Address needs a city and a state to validate, so a submission missing
    # either can't become a new address — skip it rather than failing the whole
    # registration over an optional answer. The answers stay on the form
    # submission, and the linking page still shows them for an admin to enter.
    def storable?
      @state.present?
    end

    def create_address(make_primary)
      @organization.addresses.create!(
        # street/ZIP are NOT NULL with no default, so a skipped answer has to
        # land as "" rather than nil.
        street_address: @street_address.to_s,
        city: @city,
        state: @state,
        zip_code: @zip_code.to_s,
        country: @country,
        locality: "Unknown",
        address_type: "work",
        primary: make_primary
      )
    end

    def nothing_saved
      Result.new(address: nil, created: false, filled: [])
    end
  end
end
