module AddressServices
  # Rewrites stored address countries and states as the dropdowns store them (ADR-0009),
  # filling a locality only where it's Unknown. Form answers stay as people typed them; they're
  # translated where they become addresses instead. Each changed address is one autochange
  # Ahoy event, all in one visit. Idempotent, so it runs before and after an import.
  class TranslateExisting
    Result = Data.define(:addresses, :changes, :unmatched, :rows)
    # One field one address changed (or would change, on a dry run), and whose address it is.
    Row = Data.define(:address_id, :person_id, :organization_id, :field, :before, :after)
    ROW_HEADERS = Row.members.freeze

    REASON = "address_translation"

    # `log` receives one line per changed address, for the rake task's preview.
    def initialize(dry_run: false, log: nil, user: nil)
      @dry_run = dry_run
      @log = log
      @user = user
    end

    def call
      @translation = AddressTranslation.new
      @tracker = Ahoy::Tracker.new(user: @user)
      @changes = Hash.new(0)
      @rows = []
      addresses = 0

      ActiveRecord::Base.transaction do
        Address.find_each { |address| addresses += 1 if translate(address) }
      end

      Result.new(addresses:, changes: @changes, unmatched: @translation.unmatched, rows: @rows)
    end

    private

    def translate(address)
      state = @translation.state(address.state, country: address.country)
      country = @translation.country(address.country, state: address.state)
      updates = {}
      updates[:state] = state if state.present? && state != address.state
      updates[:country] = country if country != address.country
      if address.locality.blank? || address.locality == Address::UNKNOWN_LOCALITY
        locality = @translation.locality(city: address.city, state:, country:, county: address.county)
        updates[:locality] = locality if locality != address.locality
      end
      apply(address, updates)
    end

    def apply(address, updates)
      return false if updates.empty?

      person_id = address.addressable_id if address.addressable_type == "Person"
      organization_id = address.addressable_id if address.addressable_type == "Organization"
      updates.each do |field, after|
        @changes["Address #{field}: #{address[field].inspect} → #{after.inspect}"] += 1
        @rows << Row.new(address_id: address.id, person_id:, organization_id:, field:, before: address[field], after:)
      end
      @log&.call("  Address ##{address.id}: #{updates.map { |field, after| "#{field} #{address[field].inspect} → #{after.inspect}" }.join(', ')}")
      return true if @dry_run

      changes = updates.to_h { |field, after| [ field, { before: address[field], after: } ] }
      address.update_columns(updates)
      @tracker.track("autochange.address", {
        resource_type: "Address", resource_id: address.id, resource_title: address.name, changes:, reason: REASON,
        addressable_type: address.addressable_type, addressable_id: address.addressable_id
      })
      true
    end
  end
end
