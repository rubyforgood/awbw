module EventRegistrationServices
  # Records a registrant's answers to one form a ticket callout delivers inline.
  # One submission per (registrant, form, event) so re-submitting edits in place.
  #
  # An anonymous form (Form#anonymous?) credits the registrant only when the answers
  # give first name, last name, and email (Form#identified_by?). Otherwise the
  # answers are stored with no person and a FormCompletion records only that the
  # registrant finished the form; it then can't be re-submitted or edited.
  #
  # A survey-role form additionally writes the anonymity / name-display answers through
  # to the Person (PersonServices::SyncSharingPreferences, the same write-through the
  # registration form runs; #profile_changes reports real changes for Ahoy), and
  # stamps post_survey_completed_at for a recipient's post-event survey.
  #
  # Quote fields become unpublished Quotes (Quotes::CaptureFromSubmission) on both
  # paths; an anonymous submission's quote has no creator.
  class CalloutFormSubmission
    attr_reader :submission, :profile_changes

    # Whether this call edited an existing submission rather than recording a first one.
    def edited? = @edited

    # An anonymous form the registrant already completed; nothing was saved.
    def already_completed? = @already_completed

    # An anonymous submission missing a required answer; nothing was saved.
    def incomplete? = @incomplete

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
      @already_completed = false
      @incomplete = false
    end

    def call
      person = @registration.registrant
      return record_anonymously(person) if @form.anonymous? && !@form.identified_by?(@form_params)

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

    # A credited submission edited down to a partial identity is detached from the
    # registrant rather than duplicated, so their earlier answers — and the activity
    # log of them — go anonymous too.
    def record_anonymously(person)
      event = @registration.event
      return @already_completed = true if FormCompletion.exists?(person:, form: @form, event:)
      return @incomplete = true if missing_required_answer?

      # No user or source, so a logged-in registrant is left off every record and no activity is tracked.
      Current.set(user: nil, source: nil) do
        ActiveRecord::Base.transaction do
          @submission = FormSubmission.find_by(person:, form: @form, event:)
          @edited = @submission.present?
          @submission ||= FormSubmission.new(form: @form, event:, role: @form.role)
          @submission.update!(person: nil, created_by_id: nil, updated_by_id: nil)
          if @edited
            @submission.form_answers.update_all(created_by_id: nil, updated_by_id: nil)
            @submission.quotes.update_all(created_by_id: nil, updated_by_id: nil)
            Analytics::AnonymizeSubmissionEvents.call(@submission)
          end
          @submission.record_callout_collection!(@callout)
          save_answers
          FormCompletion.record!(person:, form: @form, event:)
          OtherResponses::CaptureFromSubmission.call(@submission)
          Quotes::CaptureFromSubmission.call(@submission)
          stamp_scholarship_form_completion
        end
      end
      @submission
    end

    def missing_required_answer?
      fields = @form.form_fields.reject(&:group_header?)
      FormAnswerValidator.call(fields, @form_params).any?
    end

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
