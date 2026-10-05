module OrganizationServices
  # Resolves and fills in the registrant's organization from a submitted form, the
  # same way for an event registration and a standalone form: the organization is
  # looked up by name (never created here — an unmatched name is left for an admin
  # to resolve), then its website, type (with "Other" folded in), and work address
  # are synced from the answers. A submitted answer overwrites the org's website
  # and type, and an address the org doesn't already have is added as another work
  # address rather than rewriting one (see UpsertAddress).
  #
  # `person:` is what turns the capture into a relationship: given one, the person
  # gets their affiliation(s) with the org, and `facilitator_training:` decides
  # whether a standing "Facilitator" affiliation is minted alongside the job
  # affiliation. Omit it to fill the org in without affiliating anyone — what an
  # ordinary standalone form does, since answering a position question on a survey
  # shouldn't quietly create a formal affiliation.
  #
  # Agreement-role submissions don't come through here at all: they run
  # LinkSubmittedOrganization, which owns scenario end-dating and the job start
  # date (ADR-0002).
  #
  # Returns the matched organization (or nil) and the autofill changes the form
  # wrote onto it, so the event flow can record them on its registration↔org link.
  class CaptureFromSubmission
    Result = Struct.new(:organization, :autofill, keyword_init: true)

    def self.call(form:, form_params: {}, person: nil, facilitator_training: false, training_date: nil, event_registration: nil)
      new(form:, form_params:, person:, facilitator_training:, training_date:, event_registration:).call
    end

    def initialize(form:, form_params: {}, person: nil, facilitator_training: false, training_date: nil, event_registration: nil)
      @form = form
      @form_params = (form_params || {}).transform_keys(&:to_s)
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
        organization_type: field_value("organization_type")
      ).changes

      address_result = UpsertAddress.call(
        organization: organization,
        street_address: field_value("organization_street"),
        city: field_value("organization_city"),
        state: field_value("organization_state"),
        zip_code: field_value("organization_zip"),
        country: field_value("organization_country")
      )

      create_affiliations(organization, address_result.address)

      Result.new(organization: organization, autofill: profile_changes + address_result.changes)
    end

    private

    def create_affiliations(organization, organization_address)
      return unless @person

      AffiliationServices::CreateFromRegistration.call(
        person: @person,
        organization: organization,
        job_title: field_value(FormField::ORGANIZATION_POSITION_FIELD_IDENTIFIER),
        training_date: @training_date,
        organization_address: organization_address,
        facilitator_training: @facilitator_training,
        event_registration: @event_registration
      )
    end

    def find_organization
      name = field_value(FormField::ORGANIZATION_NAME_FIELD_IDENTIFIER)&.strip
      return nil if name.blank?

      Organization.find_by(name: name)
    end

    def field_value(key)
      field = @form.form_fields.find_by(field_identifier: key)
      return nil unless field
      @form_params[field.id.to_s]
    end
  end
end
