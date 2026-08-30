module EventRegistrationServices
  # Records a registrant's answers to the form a ticket callout delivers inline.
  # One submission per (registrant, form, event) so re-submitting edits in place.
  class CalloutFormSubmission
    def self.call(registration:, callout:, form_params:)
      new(registration:, callout:, form_params:).call
    end

    # The submission carries the form's own role — indistinguishable from the same
    # form submitted elsewhere. That a callout collected it is recorded separately,
    # in metadata (see FormSubmission#collected_via_callout?).
    def self.role_for(callout)
      callout.form&.role
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
        submission.record_callout_collection!(@callout)
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
