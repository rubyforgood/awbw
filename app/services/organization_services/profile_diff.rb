module OrganizationServices
  # Read-only comparison of a registrant's submitted org answers (website +
  # organization type) against an organization's saved profile. Surfaces the
  # discrepancies where the submitted value differs from a value already on the
  # org — i.e. the answers the fill-blanks sync will NOT apply, so an admin can
  # decide whether to update the org by hand.
  #
  # A blank submitted value, or a submitted value against a blank org column, is
  # not a discrepancy (nothing to reconcile — the latter just gets filled).
  # Powers both the linking flow's flash summary and the linking page's
  # persistent per-org note.
  class ProfileDiff
    Discrepancy = Struct.new(:field, :label, :submitted, :saved, keyword_init: true)

    def self.call(organization:, website: nil, agency_type: nil)
      new(organization:, website:, agency_type:).call
    end

    def initialize(organization:, website: nil, agency_type: nil)
      @organization = organization
      @website = website
      @agency_type = agency_type
    end

    def call
      [ website_discrepancy, agency_type_discrepancy ].compact
    end

    private

    def website_discrepancy
      submitted = @website&.strip
      saved = @organization.website_url
      return if submitted.blank? || saved.blank?
      return if normalize_url(submitted) == normalize_url(saved)

      Discrepancy.new(field: :website_url, label: "Website", submitted: submitted, saved: saved)
    end

    def agency_type_discrepancy
      submitted_label, submitted_other = parse_agency_type(@agency_type)
      return if submitted_label.blank?
      return if @organization.agency_type.blank?

      submitted = display_type(submitted_label, submitted_other)
      saved = display_type(@organization.agency_type, @organization.agency_type_other)
      return if submitted.casecmp?(saved)

      Discrepancy.new(field: :agency_type, label: "Type", submitted: submitted, saved: saved)
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
