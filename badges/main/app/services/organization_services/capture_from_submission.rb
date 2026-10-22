module OrganizationServices
  # Resolves and fills in the registrant's organization from a submitted form, the
  # same way for an event registration and a standalone form: the organization is
  # looked up by name (never created here — an unmatched name is left for an admin
  # to resolve), then its website, type (with "Other" folded in), and work address
  # are synced from the answers. A submitted answer overwrites the org's website
  # and type, and an address the org doesn't already have is added as another work
  # address rather than rewriting one (see UpsertAddress).
  #
  # The person then gets their affiliation(s) with the org, titled from the typed
  # position. `facilitator_training:` decides whether a standing "Facilitator"
  # affiliation is minted alongside the job one — true only for a facilitator
  # training. A standalone form has no event, so it passes false and only the job
  # affiliation is created, the same as registering for a non-training event.
  #
  # Agreement-role submissions don't come through here at all: they run
  # LinkSubmittedOrganization, which owns scenario end-dating and the job start
  # date (ADR-0002).
  #
  # Returns the matched organization (or nil) and the autofill changes the form
  # wrote onto it, so the event flow can record them on its registration↔org link.
  class CaptureFromSubmission
    Result = Struct.new(:organization, :autofill, keyword_init: true)

    def self.call(person:, form: nil, form_params: {}, facilitator_training: false, training_date: nil, event_registration: nil,
                  submission: nil, answers: nil, organization: nil, overwrite: true)
      new(person:, form:, form_params:, facilitator_training:, training_date:, event_registration:, submission:,
          answers:, organization:, overwrite:).call
    end

    # `answers` (field_identifier => value) stands in for form + form_params, and
    # `organization` for the by-name lookup, when a caller has already resolved them
    # (the spreadsheet importer). `overwrite: false` only fills the org's blanks.
    def initialize(person:, form: nil, form_params: {}, facilitator_training: false, training_date: nil, event_registration: nil,
                   submission: nil, answers: nil, organization: nil, overwrite: true)
      @submission = submission
      @form = form
      @form_params = (form_params || {}).transform_keys(&:to_s)
      @answers = answers&.transform_keys(&:to_s)
      @organization = organization
      @overwrite = overwrite
      @person = person
      @facilitator_training = facilitator_training
      @training_date = training_date
      @event_registration = event_registration
    end

    def call
      organization = find_organization
      return Result.new(organization: nil, autofill: []) unless organization

      profile_changes = SyncProfile.call(
        organization: organization,
        website: field_value("organization_website"),
        organization_type: field_value("organization_type"),
        overwrite: @overwrite,
        submission: @submission
      ).changes

      address_result = UpsertAddress.call(
        organization: organization,
        street_address: field_value("organization_street"),
        city: field_value("organization_city"),
        state: field_value("organization_state"),
        zip_code: field_value("organization_zip"),
        country: field_value("organization_country"),
        overwrite: @overwrite
      )

      AffiliationServices::CreateFromRegistration.call(
        person: @person,
        organization: organization,
        job_title: field_value(FormField::ORGANIZATION_POSITION_FIELD_IDENTIFIER),
        training_date: @training_date,
        organization_address: address_result.address,
        facilitator_training: @facilitator_training,
        event_registration: @event_registration
      )

      Result.new(organization: organization, autofill: profile_changes + address_result.changes)
    end

    private

    def find_organization
      return @organization if @organization

      name = field_value(FormField::ORGANIZATION_NAME_FIELD_IDENTIFIER)&.strip
      return nil if name.blank?

      Organization.find_by(name: name)
    end

    def field_value(key)
      return @answers[key] if @answers

      field = @form.form_fields.find_by(field_identifier: key)
      return nil unless field
      @form_params[field.id.to_s]
    end
  end
end
