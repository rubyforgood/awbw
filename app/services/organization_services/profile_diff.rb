module OrganizationServices
  # Read-only comparison of a registrant's submitted org answers (website,
  # organization type, and work address) against an organization's saved
  # profile. Run after the sync, what remains are the answers it couldn't apply
  # (invalid, unsaveable, or a city/state it won't move an address for), so an
  # admin can decide whether to update the org by hand.
  #
  # A website answer that isn't a web address is always a discrepancy (with a
  # reason), since the sync never saves it. Otherwise a blank submitted value, or a
  # submitted value against a blank org column, is not a discrepancy (nothing to
  # reconcile — the latter just gets filled, and
  # EventRegistrationOrganization#form_autofill_changes records that it was).
  # Address is compared against the org's corresponding address (AddressMatcher,
  # the one the upsert targets); an address the matcher doesn't
  # recognize isn't a discrepancy because it's added rather than reconciled.
  # Given the person, it also flags their affiliations here (the submitted
  # position, and Facilitator) already tied to a different org address — the
  # linking core only fills an affiliation's blank address.
  # Powers both the linking flow's flash summary and the linking page's
  # persistent per-org note.
  class ProfileDiff
    # reason: why the answer wasn't applied when it isn't simply "differs from what's
    # saved" — e.g. a website answer that isn't a web address, which is reported even
    # when the org has no website, so no submitted answer is dropped silently.
    Discrepancy = Struct.new(:field, :label, :submitted, :saved, :reason, keyword_init: true) do
      # Plain text (callers escape or let ERB escape it): form: “…”, saved: “…” — reason
      def summary
        text = "form: “#{submitted}”"
        text += ", saved: “#{saved}”" if saved.present?
        text += " — #{reason}" if reason.present?
        text
      end
    end

    NOT_A_WEB_ADDRESS = "not a web address".freeze
    ADDRESS_PARTS = %i[street_address city state zip_code country].freeze

    def self.call(organization:, website: nil, organization_type: nil, address: {}, person: nil, position: nil)
      new(organization:, website:, organization_type:, address:, person:, position:).call
    end

    # Compares the website, type, and address of a FormSubmission#org_entry-shaped
    # hash — and, given the person, their affiliations' addresses.
    def self.for_entry(organization:, entry:, person: nil)
      call(organization:, website: entry[:website], organization_type: entry[:organization_type], address: entry[:address],
           person:, position: entry[:position])
    end

    def initialize(organization:, website: nil, organization_type: nil, address: {}, person: nil, position: nil)
      @organization = organization
      @website = website
      @organization_type = organization_type
      @address = address || {}
      @person = person
      @position = position&.strip.presence
    end

    def call
      [ website_discrepancy, organization_type_discrepancy, *address_discrepancies, *affiliation_address_discrepancies ].compact
    end

    private

    def website_discrepancy
      submitted = @website&.strip
      saved = @organization.website_url
      return if submitted.blank?
      # SyncProfile never saves a non-address answer, so it's reported whether or
      # not the org has a website — otherwise it would vanish without a trace.
      unless Organization.website_address?(submitted)
        return Discrepancy.new(field: :website_url, label: "Website", submitted: submitted, saved: saved.presence,
                               reason: NOT_A_WEB_ADDRESS)
      end
      return if saved.blank?
      return if normalize_url(submitted) == normalize_url(saved)

      Discrepancy.new(field: :website_url, label: "Website", submitted: submitted, saved: saved)
    end

    def organization_type_discrepancy
      submitted_label, submitted_other = parse_organization_type(@organization_type)
      return if submitted_label.blank?
      return if @organization.organization_type.blank?

      submitted = display_type(submitted_label, submitted_other)
      saved = display_type(@organization.organization_type, @organization.organization_type_other)
      return if submitted.casecmp?(saved)

      Discrepancy.new(field: :organization_type, label: "Type", submitted: submitted, saved: saved)
    end

    # Compare every address field against the org's corresponding address. A field
    # blank on either side is skipped (the blank gets filled, not reconciled).
    # Street compares through AddressNormalizer — the same key AddressMatcher used
    # to pick this address — so "12 E. Main St" vs "12 East Main Street" isn't
    # flagged as a difference the matcher already treated as the same place.
    # City can differ here because AddressMatcher's last resort matches on
    # street + ZIP across cities — that's exactly the respelled-city case an admin
    # should see rather than have silently normalized away.
    # With no matching address, the answer is normally added as a new work address
    # (nothing to reconcile) — unless UpsertAddress can't store it, which is
    # reported rather than dropped silently.
    def address_discrepancies
      existing = matching_address
      return [ unsaved_address_discrepancy ].compact unless existing

      [
        field_discrepancy(:address_street, "Address – street", @address[:street_address], existing.street_address,
                          normalize: AddressNormalizer.method(:street)),
        field_discrepancy(:address_city, "Address – city", @address[:city], existing.city),
        field_discrepancy(:address_state, "Address – state", @address[:state], existing.state),
        field_discrepancy(:address_zip, "Address – ZIP", @address[:zip_code], existing.zip_code),
        field_discrepancy(:address_country, "Address – country", @address[:country], existing.country)
      ].compact
    end

    # Mirrors when UpsertAddress saves nothing: no city at all, or no state for an
    # address the org doesn't already have (a new Address needs both).
    def unsaved_address_discrepancy
      submitted = ADDRESS_PARTS.filter_map { |part| address_answer(part) }.join(", ")
      return if submitted.blank?

      reason = if address_answer(:city).nil? then "no city, so it wasn't saved"
      elsif address_answer(:state).nil? then "no state, so it wasn't saved"
      end
      return unless reason

      Discrepancy.new(field: :address, label: "Address", submitted: submitted, reason: reason)
    end

    def address_answer(part)
      @address[part]&.strip.presence
    end

    # The affiliations AffiliationServices::CreateFromRegistration would anchor to
    # the submitted address (the job one titled with the position, and the standing
    # Facilitator one) but won't, because they already point at another address.
    def affiliation_address_discrepancies
      return [] unless @person

      address = matching_address
      return [] unless address

      @person.affiliations.active_or_pending.where(organization: @organization).includes(:organization_address)
        .select { |affiliation| affiliation.facilitator? || (@position && affiliation.title.to_s.strip == @position) }
        .select { |affiliation| affiliation.organization_address && affiliation.organization_address_id != address.id }
        .map do |affiliation|
          Discrepancy.new(field: :affiliation_address, label: "#{affiliation.title} affiliation – address",
                          submitted: address.name.squish, saved: affiliation.organization_address.name.squish)
        end
    end

    def matching_address
      return @matching_address if defined?(@matching_address)

      @matching_address = AddressMatcher.call(
        @organization,
        city: @address[:city],
        state: @address[:state],
        street_address: @address[:street_address],
        zip_code: @address[:zip_code]
      )
    end

    def field_discrepancy(field, label, submitted, saved, normalize: nil)
      submitted = submitted&.strip.presence
      # Strip both sides: a legacy row can hold a padded street/ZIP, and comparing
      # it raw would flag the address as differing from the answer it came from.
      saved = saved&.strip.presence
      return if submitted.blank? || saved.blank?
      return if submitted.casecmp?(saved)
      return if normalize && normalize.call(submitted) == normalize.call(saved)

      Discrepancy.new(field: field, label: label, submitted: submitted, saved: saved)
    end

    # Split an "Other: <text>" answer into [ label, free_text ] the same way
    # OrganizationServices::SyncProfile stores it, so we compare like for like.
    def parse_organization_type(raw)
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
