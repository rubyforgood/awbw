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
    # changes: AutofillChange per column this call actually wrote from the form —
    # the field and the value that landed in it — so the caller can tell the admin
    # what was saved and to what. Answers that differ from a value already on the
    # org (and so weren't applied under fill-blanks) are reported separately by
    # OrganizationServices::ProfileDiff.
    Result = Struct.new(:organization, :changes, keyword_init: true)

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
      @changes = []
      # Snapshot before each write — what was there decides whether the form filled
      # a blank or replaced something an admin may have curated.
      website_before = @organization.website_url
      @changes << change("website_url", "Website", @organization.website_url, website_before) if apply_value(:website_url, @website)
      type_before = displayed_agency_type
      @changes << change("agency_type", "Type", displayed_agency_type, type_before) if sync_agency_type
      Result.new(organization: @organization, changes: @changes)
    end

    private

    # Read the new value back off the org rather than off the answer, so what we
    # report is what was actually stored (stripped, "Other" folded back together).
    def change(field, label, value, previous_value)
      AutofillChange.new(field: field, label: label, value: value, previous_value: previous_value)
    end

    def displayed_agency_type
      other = @organization.agency_type_other
      other.present? ? "#{@organization.agency_type}: #{other}" : @organization.agency_type
    end

    def sync_agency_type
      raw = @agency_type&.strip
      return false if raw.blank?
      return false if !@overwrite && @organization.agency_type.present?

      label, _separator, specified = raw.partition(":")
      label = label.strip
      return false if label.blank?
      other_text = FormField.other_option?(label) ? specified.strip.presence : nil
      @organization.update!(agency_type: label, agency_type_other: other_text)
      capture_organization_type_other(other_text)
      changed?(:agency_type, :agency_type_other)
    end

    def capture_organization_type_other(text)
      return if text.blank?

      @organization.other_responses.find_or_create_by!(
        field_identifier: OtherResponse::ORGANIZATION_TYPE_FIELD_IDENTIFIER,
        normalized_text: OtherResponse.normalize(text)
      ) { |response| response.text = text }
    end

    def apply_value(attribute, value)
      return false if value.blank?
      return false if !@overwrite && @organization.public_send(attribute).present?
      @organization.update!(attribute => value.strip)
      changed?(attribute)
    end

    # Read what was written off saved_changes rather than off what we assigned, so
    # a registrant resubmitting the values already on file isn't reported as having
    # changed the org.
    def changed?(*attributes)
      attributes.any? { |attribute| @organization.saved_changes.key?(attribute.to_s) }
    end
  end
end
