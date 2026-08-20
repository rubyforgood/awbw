module EventRegistrationServices
  # Records a survey as a role-tagged FormSubmission: static answers plus dynamic
  # "clarity" answers (a per-resource field fans out to one nil-form_field answer per
  # resource, its sentence snapshotted in question_name_when_answered). The anonymity
  # and name-display questions also write through to the Person (#profile_changes
  # reports real changes for Ahoy). Stamps post_survey_completed_at for a recipient's
  # recipients survey. Idempotent on re-submit.
  class SurveySubmission
    attr_reader :submission, :profile_changes

    def self.call(**kwargs)
      instance = new(**kwargs)
      instance.call
      instance
    end

    def initialize(event_registration:, form:, role:, field_params: {}, clarity_params: {})
      @event_registration = event_registration
      @form = form
      @role = role
      @field_params = (field_params || {}).transform_keys(&:to_s)
      @clarity_params = clarity_params || {}
      @profile_changes = {}
    end

    def call
      person = @event_registration.registrant
      ActiveRecord::Base.transaction do
        @submission = FormSubmission.find_or_create_by!(
          person: person, form: @form, event: @event_registration.event, role: @role
        )
        save_static_answers
        save_clarity_answers
        sync_profile(person)
        stamp_completion
      end
      @submission
    end

    private

    def save_static_answers
      @form.form_fields.each do |field|
        next if field.answer_type == "group_header" || field.per_resource?
        raw = @field_params[field.id.to_s]
        next if raw.nil?
        text = raw.is_a?(Array) ? raw.reject(&:blank?).join(", ") : raw
        record = @submission.form_answers.find_or_initialize_by(form_field: field)
        record.update!(submitted_answer: text, question_name_when_answered: field.name)
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
          question = "#{field.name} #{link.resource.title}"
          record = @submission.form_answers.find_or_initialize_by(form_field: nil, question_name_when_answered: question)
          record.update!(submitted_answer: raw)
        end
      end
    end

    # Write the two identified questions to the Person, recording only real changes.
    def sync_profile(person)
      apply_profile_change(person, :anonymous_contributions,
        Person::ANONYMOUS_CONTRIBUTIONS_OPTIONS.invert[value_for("anonymous_contributions")])
      apply_profile_change(person, :display_name_preference,
        Person::DISPLAY_NAME_PREFERENCE_LABELS.invert[value_for("display_name_preference")])
      person.save! if person.changed?
    end

    def apply_profile_change(person, attribute, new_value)
      return if new_value.nil?
      current = person.public_send(attribute)
      return if current == new_value
      @profile_changes[attribute] = [ current, new_value ]
      person.public_send("#{attribute}=", new_value)
    end

    # The submitted label for a field identified by its field_identifier.
    def value_for(field_identifier)
      field = @form.form_fields.find_by(field_identifier: field_identifier)
      field && @field_params[field.id.to_s]
    end

    def stamp_completion
      return unless @role == "post_event_survey" && @event_registration.scholarship?
      return if @event_registration.post_survey_completed?
      @event_registration.mark_post_survey_completed!
    end
  end
end
