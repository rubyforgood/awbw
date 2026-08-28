module EventRegistrationServices
  # Records a registrant's answers to the form a ticket callout delivers inline.
  # One submission per (registrant, form, event) so re-submitting edits in place.
  class CalloutFormSubmission
    # Fallback when the form carries no role, or one reserved for a dedicated
    # event-form flow (which the callout picker excludes but a console/seed could set).
    FALLBACK_ROLE = "callout".freeze

    def self.call(registration:, callout:, form_params:)
      new(registration:, callout:, form_params:).call
    end

    # Mirror the form's own role so a callout submission looks like any other
    # submission of that form (uniform stats/lookups), guarding the reserved roles.
    def self.role_for(callout)
      role = callout.form&.role&.presence
      return FALLBACK_ROLE if role.nil? || EventForm::ROLES.include?(role)
      role
    end

    def initialize(registration:, callout:, form_params:)
      @registration = registration
      @callout = callout
      @form_params = form_params || {}
    end

    def call
      form = @callout.form
      ActiveRecord::Base.transaction do
        submission = FormSubmission.find_or_create_by!(
          person: @registration.registrant, form: form, event: @registration.event,
          role: self.class.role_for(@callout)
        )
        @form_params.each do |field_id, raw_value|
          field = form.form_fields.find_by(id: field_id)
          next unless field
          next if field.group_header?
          submission.persist_answer(field, raw_value)
        end
        submission
      end
    end
  end
end
