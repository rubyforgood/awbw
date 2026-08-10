module OrganizationServices
  # Read-only comparison of a registrant's submitted org answers (website,
  # organization type, and work address) against an organization's saved
  # profile. Surfaces the answers the org doesn't carry, so an admin can decide
  # whether to enter them by hand.
  #
  # Website and type are reported whenever they differ from the org's value AND
  # when the org's column is blank, because linking an existing org no longer
  # autofills either (only an org created from the submission is seeded).
  # `saved` is nil on the blank case.
  #
  # Address is different: the upsert still fills blank fields on the org's
  # corresponding address, so only a genuine conflict is reported. It's compared
  # against the address AddressMatcher picks (the one the upsert targets); an
  # address the matcher doesn't recognize isn't a discrepancy because it's added
  # rather than reconciled. A blank submitted value is never a discrepancy.
  # Powers both the linking flow's flash summary and the linking page's
  # persistent per-org note.
  class ProfileDiff
    Discrepancy = Struct.new(:field, :label, :submitted, :saved, keyword_init: true)

    def self.call(organization:, website: nil, agency_type: nil, address: {})
      new(organization:, website:, agency_type:, address:).call
    end

    def initialize(organization:, website: nil, agency_type: nil, address: {})
      @organization = organization
      @website = website
      @agency_type = agency_type
      @address = address || {}
    end

    def call
      [ website_discrepancy, agency_type_discrepancy, *address_discrepancies ].compact
    end

    private

    def website_discrepancy
      submitted = @website&.strip
      return if submitted.blank?

      saved = @organization.website_url.presence
      return if saved && normalize_url(submitted) == normalize_url(saved)

      Discrepancy.new(field: :website_url, label: "Website", submitted: submitted, saved: saved)
    end

    def agency_type_discrepancy
      submitted_label, submitted_other = parse_agency_type(@agency_type)
      return if submitted_label.blank?

      submitted = display_type(submitted_label, submitted_other)
      saved = @organization.agency_type.presence && display_type(@organization.agency_type, @organization.agency_type_other)
      return if saved && submitted.casecmp?(saved)

      Discrepancy.new(field: :agency_type, label: "Type", submitted: submitted, saved: saved)
    end

    # Compare every address field against the org's corresponding address. A field
    # blank on either side is skipped (the blank gets filled, not reconciled).
    # City can differ here because AddressMatcher's last resort matches on
    # street + ZIP across cities — that's exactly the respelled-city case an admin
    # should see rather than have silently normalized away.
    def address_discrepancies
      existing = matching_address
      return [] unless existing

      [
        field_discrepancy(:address_street, "Address – street", @address[:street_address], existing.street_address),
        field_discrepancy(:address_city, "Address – city", @address[:city], existing.city),
        field_discrepancy(:address_state, "Address – state", @address[:state], existing.state),
        field_discrepancy(:address_zip, "Address – ZIP", @address[:zip_code], existing.zip_code),
        field_discrepancy(:address_country, "Address – country", @address[:country], existing.country)
      ].compact
    end

    def matching_address
      AddressMatcher.call(
        @organization,
        city: @address[:city],
        state: @address[:state],
        street_address: @address[:street_address],
        zip_code: @address[:zip_code]
      )
    end

    def field_discrepancy(field, label, submitted, saved)
      submitted = submitted&.strip.presence
      saved = saved.presence
      return if submitted.blank? || saved.blank?
      return if submitted.casecmp?(saved)

      Discrepancy.new(field: field, label: label, submitted: submitted, saved: saved)
    end

    # Split an "Other: <text>" answer into [ label, free_text ] the same way
    # OrganizationServices::SyncProfile stores it, so we compare like for like.
    def parse_agency_type(raw)
      stripped = raw&.strip
      return [ nil, nil ] if stripped.blank?

      label, _separator, specified = stripped.partition(":")
      label = label.strip
      other = FormField.other_option?(label) ? specified.strip.presence : nil
      [ label.presence, other ]
    end

    def display_type(label, other)
      other.present? ? "#{label}: #{other}" : label
    end

    def normalize_url(url)
      url.to_s.strip.downcase.sub(%r{\Ahttps?://}, "").delete_prefix("www.").chomp("/")
    end
  end
end
