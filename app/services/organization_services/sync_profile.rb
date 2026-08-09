module OrganizationServices
  # Populate an organization's structured profile columns — website_url and
  # agency_type/agency_type_other — from a registrant's submitted answers.
  # A non-blank submitted value overwrites what's on file (the latest
  # registration is the freshest source of truth; the prior value survives in
  # the Ahoy audit trail); a blank answer never clobbers existing data.
  #
  # The "Organization Type" answer folds an "Other" choice's free text in as
  # "Other: <text>": we split the option label (drives agency_type) from the
  # typed text (fills agency_type_other, cleared for non-"Other" so no stale
  # text lingers) and record the free text as an OtherResponse for the curation
  # queue. Shared by the public registration flow and the admin
  # create-and-link action so both build the org profile identically.
  #
  # overwrite: (default true) reflects the public flow's latest-wins contract —
  # a non-blank answer replaces what's on file. The admin create-and-link flow
  # passes overwrite: false so it only fills columns that are currently blank,
  # never clobbering an existing org's curated type/website.
  class SyncProfile
    def self.call(organization:, website: nil, agency_type: nil, overwrite: true)
      new(organization:, website:, agency_type:, overwrite:).call
    end

    def initialize(organization:, website: nil, agency_type: nil, overwrite: true)
      @organization = organization
      @website = website
      @agency_type = agency_type
      @overwrite = overwrite
    end

    def call
      apply_value(:website_url, @website)
      sync_agency_type
      @organization
    end

    private

    def sync_agency_type
      raw = @agency_type&.strip
      return if raw.blank?
      return if !@overwrite && @organization.agency_type.present?

      label, _separator, specified = raw.partition(":")
      label = label.strip
      return if label.blank?
      other_text = FormField.other_option?(label) ? specified.strip.presence : nil
      @organization.update!(agency_type: label, agency_type_other: other_text)
      capture_organization_type_other(other_text)
    end

    def capture_organization_type_other(text)
      return if text.blank?

      @organization.other_responses.find_or_create_by!(
        field_identifier: OtherResponse::ORGANIZATION_TYPE_FIELD_IDENTIFIER,
        normalized_text: OtherResponse.normalize(text)
      ) { |response| response.text = text }
    end

    def apply_value(attribute, value)
      return if value.blank?
      return if !@overwrite && @organization.public_send(attribute).present?
      @organization.update!(attribute => value.strip)
    end
  end
end
