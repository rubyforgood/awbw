module EventRegistrationServices
  # Records a registrant's answers to one form a ticket callout delivers inline.
  # One submission per (registrant, form, event) so re-submitting edits in place.
  #
  # A survey-role form additionally: fans a per-resource "clarity" field out to one
  # answer per linked resource, writes the anonymity / name-display answers through
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

    def initialize(registration:, callout:, form:, form_params: {}, clarity_params: {})
      @registration = registration
      @callout = callout
      @form = form
      @form_params = (form_params || {}).transform_keys(&:to_s)
      @clarity_params = clarity_params || {}
      @profile_changes = {}
    end

    def call
      person = @registration.registrant
      ActiveRecord::Base.transaction do
        @submission = FormSubmission.find_or_create_by!(
          person: person, form: @form, event: @registration.event, role: @form.role
        )
        # Capture first-time vs. edit before the metadata update below flips the flag.
        @edited = !@submission.previously_new_record?
        @submission.record_callout_collection!(@callout)
        save_answers
        # These run for any callout form and self-gate on the form's own fields:
        # clarity fans out only per-resource fields, and the profile write-through
        # only fires when the form asks the identified anonymity / name questions.
        save_clarity_answers
        sync_profile(person)
        stamp_scholarship_form_completion
      end
      @submission
    end

    private

    def save_answers
      @form.form_fields.each do |field|
        next if field.group_header? || field.per_resource?
        raw = @form_params[field.id.to_s]
        next if raw.nil?
        text = raw.is_a?(Array) ? raw.reject(&:blank?).join(", ") : raw
        @submission.persist_answer(field, text)
      end
    end

    # One answer per linked resource, keyed by the snapshotted sentence so re-submits
    # update in place (form_field stays nil).
    def save_clarity_answers
      @clarity_params.each do |field_id, per_resource|
        field = @form.form_fields.find_by(id: field_id)
        next unless field&.per_resource?
        field.form_field_resources.includes(:resource).each do |link|
          raw = per_resource[link.resource_id.to_s] || per_resource[link.resource_id]
          next if raw.blank?
          question = field.per_resource_question(link.resource)
          record = @submission.form_answers.find_or_initialize_by(form_field: nil, question_name_when_answered: question)
          record.update!(submitted_answer: raw)
        end
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
