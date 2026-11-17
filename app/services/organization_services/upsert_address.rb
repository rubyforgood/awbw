module OrganizationServices
  # Find-or-create an organization's work address from a registrant's submitted
  # organization address fields. When AddressMatcher recognizes one of the org's
  # addresses as the same place, update it in place; otherwise add it as a new
  # "work" address that becomes the org's primary (the latest answer wins), taking
  # the flag off the old primary — reported as a change so staff can switch back.
  #
  # Shared by the public registration flow and the admin org-linking actions so
  # both build the org address identically. A registrant's optional answers are
  # tolerated: a skipped street/ZIP is stored blank, and a submission with no
  # state saves no new address rather than failing the registration.
  class UpsertAddress
    # address: the Address the submission was saved to — nil when the submission
    # couldn't be stored (see storable? for what a new address needs).
    # created: the submission added a new address rather than updating one.
    # changes: AutofillChange per field this call actually wrote — the field, the
    # value that landed in it, and which work address it belongs to (an org keeps
    # one per city, so "ZIP" alone wouldn't say which). Empty when nothing was
    # saved or nothing changed: a caller reporting the save must not claim more
    # than happened. A newly created address reports as one change carrying the
    # whole address rather than five, since none of it was there to begin with.
    Result = Struct.new(:address, :created, :changes, keyword_init: true)

    FIELD_LABELS = {
      "street_address" => "Street",
      "city" => "City",
      "state" => "State",
      "zip_code" => "ZIP",
      "country" => "Country",
      "county" => "County",
      "locality" => "Locality"
    }.freeze

    def self.call(organization:, city: nil, state: nil, street_address: nil, zip_code: nil, country: nil)
      new(organization:, city:, state:, street_address:, zip_code:, country:).call
    end

    def initialize(organization:, city: nil, state: nil, street_address: nil, zip_code: nil, country: nil)
      @organization = organization
      @city = city&.strip
      @state = state&.strip.presence
      @street_address = street_address&.strip
      @zip_code = zip_code&.strip
      @country = country&.strip.presence
    end

    def call
      return nothing_saved if @city.blank?

      existing = AddressMatcher.call(
        @organization, city: @city, state: @state, street_address: @street_address, zip_code: @zip_code
      )
      return nothing_saved if existing.nil? && !storable?

      unless existing
        previous_primaries = @organization.addresses.where(primary: true).to_a
        previous_primaries.each { |address| address.update!(primary: false) }
        created = create_address
        changes = [ whole_address_change(created), primary_change(created, previous_primaries.first) ].compact
        return Result.new(address: created, created: true, changes: changes)
      end

      make_primary = @organization.addresses.active.where(primary: true).none?

      existing.assign_attributes(field_updates(existing))
      # Build the changes off `changed` rather than off what we assigned, so a
      # resubmission of values already on file isn't reported as saved.
      changes = existing.changed.filter_map { |attribute| field_change(existing, attribute) }
      existing.primary = true if make_primary
      existing.inactive = false
      existing.save!

      Result.new(address: existing, created: false, changes: changes)
    end

    private

    # Named by city like the per-field changes are, so an admin reading the note
    # knows which of the org's work addresses appeared — the value carries the rest.
    def whole_address_change(address)
      AutofillChange.new(field: "address", label: "Work address in #{address.city}", value: address.name.squish)
    end

    def primary_change(created, previous)
      return unless previous

      AutofillChange.new(field: "primary_address", label: "Primary work address", value: created.name.squish,
                         previous_value: previous.name.squish)
    end

    # Called after assign_attributes and before save, so `changes` still holds the
    # [before, after] pair that says whether this filled a blank or replaced a value.
    def field_change(address, attribute)
      label = FIELD_LABELS[attribute]
      return unless label

      before, _after = address.changes[attribute]
      AutofillChange.new(
        field: attribute,
        label: label,
        value: address.public_send(attribute),
        previous_value: before,
        scope: "#{address.city} work address"
      )
    end

    # ZIP and country take the submitted value (the prior one survives in the Ahoy
    # audit trail). Street, city, and state are fill-only: they're what an address
    # is identified by (a matched address already has the same street), so
    # rewriting them would move a saved address to a different place —
    # ProfileDiff flags a differing one instead. The fill is not dead code even though both columns are NOT NULL
    # and validated present — a legacy row can hold "", and AddressMatcher's last
    # resort (street + ZIP, any city) is the one path that reaches such a row, so
    # that's where a blank city/state gets repaired. See the "repairs a legacy
    # address" specs.
    def field_updates(existing)
      updates = {}
      updates[:city] = @city if existing.city.blank?
      updates[:state] = @state if @state.present? && existing.state.blank?
      updates[:street_address] = @street_address if @street_address.present? && existing.street_address.blank?
      updates[:zip_code] = @zip_code if @zip_code.present?
      updates[:country] = @country if @country.present?
      updates.merge(filled_defaults(existing, updates))
    end

    # A blank country or county, and a blank or Unknown locality, take what AddressDefaults
    # works out from the address as updated.
    def filled_defaults(existing, updates)
      parts = existing.attributes.symbolize_keys.slice(:city, :state, :zip_code, :country, :county)
                     .merge(updates.slice(:city, :state, :zip_code, :country))
      AddressDefaults.for(**parts).select do |field, value|
        value.present? && value != Address::UNKNOWN_LOCALITY &&
          (existing[field].blank? || existing[field] == Address::UNKNOWN_LOCALITY)
      end
    end

    # An Address needs a city and a state to validate, so a submission missing
    # either can't become a new address — skip it rather than failing the whole
    # registration over an optional answer. The answers stay on the form
    # submission, and the linking page still shows them for an admin to enter.
    def storable?
      @state.present?
    end

    def create_address
      @organization.addresses.create!(
        # street/ZIP are NOT NULL with no default, so a skipped answer has to
        # land as "" rather than nil.
        street_address: @street_address.to_s,
        city: @city,
        state: @state,
        zip_code: @zip_code.to_s,
        **AddressDefaults.for(city: @city, state: @state, zip_code: @zip_code, country: @country),
        address_type: "work",
        primary: true
      )
    end

    def nothing_saved
      Result.new(address: nil, created: false, changes: [])
    end
  end
end
