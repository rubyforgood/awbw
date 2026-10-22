module EventRegistrationServices
  # Records a registrant's answers to one form a ticket callout delivers inline.
  # One submission per (registrant, form, event) so re-submitting edits in place.
  #
  # A survey-role form additionally writes the anonymity / name-display answers through
  # to the Person (PersonServices::SyncSharingPreferences, the same write-through the
  # registration form runs; #profile_changes reports real changes for Ahoy), and
  # stamps post_survey_completed_at for a recipient's post-event survey.
  class CalloutFormSubmission
    attr_reader :submission, :profile_changes

    # Whether this call edited an existing submission rather than recording a first one.
    def edited? = @edited

    def self.call(**kwargs)
      instance = new(**kwargs)
      instance.call
      instance
    end

    def initialize(registration:, callout:, form:, form_params: {})
      @registration = registration
      @callout = callout
      @form = form
      @form_params = (form_params || {}).transform_keys(&:to_s)
      @profile_changes = {}
    end

    def call
      person = @registration.registrant
      ActiveRecord::Base.transaction do
        @submission = FormSubmission.create_with(role: @form.role).find_or_create_by!(
          person: person, form: @form, event: @registration.event
        )
        # Capture first-time vs. edit before the metadata update below flips the flag.
        @edited = !@submission.previously_new_record?
        @submission.record_callout_collection!(@callout)
        save_answers
        OtherResponses::CaptureFromSubmission.call(@submission)
        Quotes::CaptureFromSubmission.call(@submission)
        # Runs for any callout form; only fires when the form asks the identified
        # anonymity / name questions.
        sync_profile(person)
        stamp_scholarship_form_completion
      end
      Current.form_submission_id = @submission.id
      @submission
    end

    private

    def save_answers
      @form.form_fields.each do |field|
        next if field.group_header?
        raw = @form_params[field.id.to_s]
        next if raw.nil?
        @submission.persist_answer(field, raw)
      end
    end

    # The same content-sharing write-through the registration flow runs, so the two
    # questions behave identically wherever they're asked.
    def sync_profile(person)
      @profile_changes = PersonServices::SyncSharingPreferences.call(
        person: person, form: @form, form_params: @form_params
      ).changes
    end

    # A form delivered on the scholarship callout is a scholarship recipient's final
    # step, so submitting it stamps their readiness for the certificate.
    def stamp_scholarship_form_completion
      return unless @callout.builtin_key == "scholarship" && @registration.scholarship?
      return if @registration.post_survey_completed?
      @registration.mark_post_survey_completed!
    end
  end
end
