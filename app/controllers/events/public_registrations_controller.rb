module Events
  class PublicRegistrationsController < ApplicationController
    skip_before_action :authenticate_user!, only: [ :new, :create, :show ]
    before_action :set_event
    before_action :ensure_registerable, only: [ :new, :create ]

    rescue_from ActionController::InvalidAuthenticityToken do
      flash[:alert] = "Your session has expired. Please try submitting the form again."
      redirect_to new_event_public_registration_path(@event)
    end

    def new
      authorize! :public_registration, to: :new?

      @form = registration_form
      unless @form
        redirect_to event_path(@event), alert: "Registration form is not available for this event."
        return
      end

      @form_fields = visible_form_fields
      @scholarship = scholarship_mode?
      @event = @event.decorate
    end

    def create
      authorize! :public_registration, to: :create?

      if params[:public_registration][:website_url].present?
        redirect_to new_event_public_registration_path(@event)
        return
      end

      @form = registration_form
      form_params = params.dig(:public_registration, :form_fields)&.to_unsafe_h || {}

      @field_errors = validate_required_fields(form_params)
      if @field_errors.any?
        @form_fields = visible_form_fields
        @scholarship = scholarship_mode?
        @event = @event.decorate
        render :new, status: :unprocessable_content
        return
      end

      Current.source = "public_registration"

      result = EventRegistrationServices::PublicRegistration.call(
        event: @event,
        form: @form,
        form_params: form_params,
        scholarship_requested: scholarship_mode?
      )

      if result.success?
        redirect_to registration_ticket_path(result.event_registration.slug),
                    notice: "You have been successfully registered!"
      else
        @form_fields = visible_form_fields
        @event = @event.decorate
        flash.now[:alert] = result.errors.join(", ")
        render :new, status: :unprocessable_content
      end
    end

    def show
      authorize! :public_registration, to: :show?

      if params[:reg].present?
        registration = EventRegistration.find_by!(slug: params[:reg], event_id: @event.id)
        person = registration.registrant
      elsif params[:person_id].present?
        person = Person.find(params[:person_id])
        registration = @event.event_registrations.find_by(registrant: person)
      else
        redirect_to event_path(@event), alert: "Registration not found."
        return
      end

      @form = registration_form
      unless @form
        redirect_to event_path(@event), alert: "Registration form not found."
        return
      end

      @form_submission = @form.form_submissions.find_by(person: person)
      unless @form_submission
        redirect_to event_path(@event), alert: "No registration form submission found."
        return
      end

      @form_fields = @form.form_fields.reorder(position: :asc)
      @responses = @form_submission.form_answers.index_by(&:form_field_id)
      @event = @event.decorate
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end

    def registration_form
      @event.registration_form
    end

    def scholarship_mode?
      params[:scholarship_requested] == "true"
    end

    def visible_form_fields
      scope = @form.form_fields

      unless scholarship_mode?
        scope = scope.where.not(visibility: :scholarship_only)
      end

      person = current_user&.person
      if person
        if @form.hide_answered_person_questions?
          known_keys = person_known_field_keys(person)
          if known_keys.any?
            known_ids = @form.form_fields
                             .where(visibility: :logged_out_only, field_key: known_keys)
                             .ids
            scope = scope.where.not(id: known_ids) if known_ids.any?
          end

          # Hide logged_out_only headers when all their non-header fields are hidden
          logged_out_groups = @form.form_fields.where(visibility: :logged_out_only)
                                  .where.not(answer_type: :group_header)
                                  .pluck(:field_group).uniq.compact
          logged_out_groups.each do |group|
            group_field_ids = @form.form_fields.where(field_group: group, visibility: :logged_out_only)
                                  .where.not(answer_type: :group_header).ids
            if group_field_ids.any? && known_keys.any? && (group_field_ids - scope.where(id: group_field_ids).ids).any?
              remaining = scope.where(id: group_field_ids).ids
              if remaining.empty?
                scope = scope.where.not(field_group: group, answer_type: :group_header, visibility: :logged_out_only)
              end
            end
          end
        end

        if @form.hide_answered_form_questions?
          answered_field_ids = []

          # One-time fields: hide if answered on ANY form submission for this person
          one_time_field_ids = @form.form_fields.where(visibility: :answers_on_file, one_time: true)
                                   .where.not(answer_type: :group_header).ids
          if one_time_field_ids.any?
            answered_one_time = FormAnswer.joins(:form_submission)
                                         .where(form_submissions: { person_id: person.id })
                                         .where(form_field_id: one_time_field_ids)
                                         .where.not(question_answer: [ nil, "" ])
                                         .pluck(:form_field_id)
            answered_field_ids.concat(answered_one_time)
          end

          # Regular fields: hide if answered on forms within this event
          event_form_ids = @event.forms.ids
          event_submissions = FormSubmission.where(person: person, form_id: event_form_ids)
          if event_submissions.exists?
            regular_field_ids = @form.form_fields.where(visibility: :answers_on_file, one_time: false)
                                     .where.not(answer_type: :group_header).ids
            if regular_field_ids.any?
              answered_regular = FormAnswer.where(form_submission: event_submissions)
                                          .where(form_field_id: regular_field_ids)
                                          .where.not(question_answer: [ nil, "" ])
                                          .pluck(:form_field_id)
              answered_field_ids.concat(answered_regular)
            end
          end

          answered_field_ids.uniq!
          if answered_field_ids.any?
            scope = scope.where.not(id: answered_field_ids)

            # Hide section headers when all their non-header fields are answered
            answered_groups = @form.form_fields.where(id: answered_field_ids)
                                  .pluck(:field_group).uniq.compact
            answered_groups.each do |group|
              group_field_ids = @form.form_fields.where(field_group: group, visibility: :answers_on_file)
                                    .where.not(answer_type: :group_header).ids
              if group_field_ids.any? && (group_field_ids - answered_field_ids).empty?
                scope = scope.where.not(field_group: group, answer_type: :group_header, visibility: :answers_on_file)
              end
            end
          end
        end
      end

      scope.reorder(position: :asc)
    end

    def person_known_field_keys(person)
      keys = []
      keys << "first_name" if person.first_name.present?
      keys << "last_name" if person.last_name.present?
      keys << "primary_email" << "confirm_email" if person.email.present?
      keys << "primary_email_type" if person.email_type.present?
      keys << "nickname" if person.legal_first_name.present? || person.first_name.present?
      keys << "pronouns" if person.pronouns.present?
      keys << "secondary_email" if person.email_2.present?
      keys << "secondary_email_type" if person.email_2_type.present?

      if person.addresses.exists?
        address = person.addresses.find_by(primary: true) || person.addresses.first
        keys << "mailing_street" if address.street_address.present?
        keys << "mailing_address_type" if address.address_type.present?
        keys << "mailing_city" if address.city.present?
        keys << "mailing_state" if address.state.present?
        keys << "mailing_zip" if address.zip_code.present?
      end

      if person.contact_methods.where(kind: :phone).exists?
        keys << "phone" << "phone_type"
      end

      keys
    end

    def ensure_registerable
      unless @event.registerable?
        redirect_to event_path(@event), alert: "Registration is closed for this event."
      end
    end

    def validate_required_fields(form_params)
      errors = {}
      fields = visible_form_fields
      fields_by_key = fields.select { |f| f.field_key.present? }.index_by(&:field_key)

      fields.find_each do |field|
        next if field.group_header?

        value = form_params[field.id.to_s]

        if field.is_required && (value.blank? || (value.is_a?(Array) && value.reject(&:blank?).empty?))
          errors[field.id] = "can't be blank"
          next
        end

        next if value.blank?

        if field.number_integer? && value.to_s !~ /\A\d+\z/
          errors[field.id] = "must be a whole number"
        elsif field.field_key&.match?(/email(?!_type|_confirmation)/) && value.to_s !~ /\A[^@\s]+@[^@\s]+\z/
          errors[field.id] = "must be a valid email address"
        end
      end

      confirm_field = fields_by_key["confirm_email"]
      email_field = fields_by_key["primary_email"]
      if confirm_field && email_field && errors[confirm_field.id].nil?
        confirm_value = form_params[confirm_field.id.to_s].to_s.strip
        email_value = form_params[email_field.id.to_s].to_s.strip
        if confirm_value.present? && confirm_value != email_value
          errors[confirm_field.id] = "must match email"
        end
      end

      errors
    end
  end
end
