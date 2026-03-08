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

      @registration_form = registration_form
      unless @registration_form
        redirect_to event_path(@event), alert: "Registration form is not available for this event."
        return
      end

      @form_fields = visible_form_fields
      @scholarship = scholarship_mode?
      @scholarship_form = @event.scholarship_form if @scholarship
      @continuing_education_form = @event.continuing_education_form
      @event = @event.decorate
    end

    def create
      authorize! :public_registration, to: :create?

      if params[:public_registration][:website_url].present?
        redirect_to new_event_public_registration_path(@event)
        return
      end

      @registration_form = registration_form
      @scholarship = scholarship_mode?
      @scholarship_form = @event.scholarship_form if @scholarship
      @continuing_education_form = @event.continuing_education_form

      all_params = params.dig(:public_registration, :form_fields)&.to_unsafe_h || {}
      registration_params, scholarship_params, continuing_education_params = split_form_params(all_params)

      @field_errors = validate_required_fields(registration_params)
      if @scholarship_form
        scholarship_fields = @scholarship_form.form_fields.where.not(answer_type: :group_header).to_a
        @field_errors = @field_errors.merge(FormAnswerValidator.call(scholarship_fields, scholarship_params))
      end
      if @continuing_education_form
        ce_fields = @continuing_education_form.form_fields.where.not(answer_type: :group_header).to_a
        @field_errors = @field_errors.merge(FormAnswerValidator.call(ce_fields, continuing_education_params))
      end
      if @field_errors.any?
        @form_fields = visible_form_fields
        @continuing_education_form = @event.continuing_education_form
        @event = @event.decorate
        flash.now[:alert] = "Your registration is not complete yet. Scroll down to check for any errors or missing information."
        render :new, status: :unprocessable_content
        return
      end

      Current.source = "public_registration"

      result = EventRegistrationServices::PublicRegistration.call(
        event: @event,
        registration_form: @registration_form,
        form_params: registration_params,
        scholarship_requested: @scholarship,
        person: current_user&.person,
        scholarship_form: @scholarship_form,
        scholarship_params: scholarship_params,
        continuing_education_form: @continuing_education_form,
        continuing_education_params: continuing_education_params
      )

      if result.success?
        registration = result.event_registration

        if !registration.scholarship_requested? && @event.cost_cents.to_i > 0 && credit_card_payment?(registration_params)
          checkout_session = create_stripe_checkout_session(registration, result.form_submission)
          redirect_to checkout_session.url, allow_other_host: true, status: :see_other
        else
          redirect_to registration_ticket_path(registration.slug, reg: params[:reg].presence),
                      notice: "You have been successfully registered!"
        end
      else
        @form_fields = visible_form_fields
        @continuing_education_form = @event.continuing_education_form
        @event = @event.decorate
        flash.now[:error] = result.errors.join(", ")
        flash.now[:alert] = "Your registration is not complete yet. Scroll down to check for any errors or missing information."
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

      @registration_form = registration_form
      unless @registration_form
        redirect_to event_path(@event), alert: "Registration form not found."
        return
      end

      # Scope submissions to this event so a person registered for multiple
      # events that share the same form sees only the answers for this one.
      submissions = @registration_form.form_submissions.where(person: person, event: @event)
      @form_submission = if params[:form_submission_id].present?
        submissions.find_by(id: params[:form_submission_id])
      else
        submissions.first
      end
      unless @form_submission
        redirect_to event_path(@event), alert: "No registration form submission found."
        return
      end

      @form_fields = visible_form_fields
      @responses = @form_submission.form_answers.index_by(&:form_field_id)

      load_scholarship_submission(person)
      load_continuing_education_submission(person)

      @event = @event.decorate
    end

    private

    def credit_card_payment?(form_params)
      payment_method_field = @registration_form.form_fields.find_by(field_identifier: "payment_method")
      return false unless payment_method_field

      form_params[payment_method_field.id.to_s]&.downcase == FormBuilderService::PAYMENT_METHOD_PAY_NOW.downcase
    end

    def create_stripe_checkout_session(registration, submission = nil)
      person = registration.registrant
      amount = @event.cost_cents

      metadata = { event_registration_id: registration.id, event_id: @event.id }
      metadata[:form_submission_id] = submission.id if submission

      person.set_payment_processor :stripe

      checkout_session = person.payment_processor.checkout(
        mode: "payment",
        metadata: metadata,
        payment_intent_data: { metadata: metadata, description: "Training Fee: #{@event.title}" },
        line_items: [ {
          price_data: {
            currency: "usd",
            product_data: { name: "Registration: #{@event.title}" },
            unit_amount: amount
          },
          quantity: 1
        } ],
        success_url: registration_ticket_url(registration.slug, checkout: "success", reg: params[:reg].presence),
        cancel_url: registration_ticket_url(registration.slug, checkout: "cancelled", reg: params[:reg].presence)
      )

      registration.update!(checkout_session_id: checkout_session.id)
      checkout_session
    end

    def set_event
      @event = Event.find(params[:event_id])
    end

    def registration_form
      @event.registration_form
    end

    # Surface the dedicated scholarship form's application in its own card on the
    # view-submission page when the registrant filled it out. Answers are gathered
    # by field identifier (they may live on the scholarship submission or on the
    # registration submission), so a registrant who answered the questions while
    # registering still sees them. Only set when answers are on file, so plain
    # registrations render nothing. Embedded-section scholarship questions need no
    # separate card — they already render inline with the registration answers.
    def load_scholarship_submission(person)
      scholarship_form = @event.scholarship_form
      return unless scholarship_form

      application = ScholarshipApplication.new(event: @event, person: person)
      return unless application.answered?

      @scholarship_submission = application.submission
      @scholarship_form = scholarship_form
      @scholarship_fields = scholarship_form.form_fields.reorder(position: :asc)
      @scholarship_responses = application.answers_by_field_id
    end

    def load_continuing_education_submission(person)
      ce_form = @event.continuing_education_form
      return unless ce_form

      submission = ce_form.form_submissions.find_by(person: person, event: @event, role: "continuing_education")
      return unless submission

      @continuing_education_submission = submission
      @continuing_education_form = ce_form
      @continuing_education_fields = ce_form.form_fields.reorder(position: :asc)
      @continuing_education_responses = submission.form_answers.index_by(&:form_field_id)
    end

    def scholarship_mode?
      params[:scholarship_requested] == "true"
    end

    def split_form_params(all_params)
      reg_field_ids = @registration_form.form_fields.pluck(:id).map(&:to_s)
      registration = all_params.slice(*reg_field_ids)

      scholarship = {}
      if @scholarship_form
        scholarship_field_ids = @scholarship_form.form_fields.pluck(:id).map(&:to_s)
        scholarship = all_params.slice(*scholarship_field_ids)
      end

      continuing_education = {}
      if @continuing_education_form
        ce_field_ids = @continuing_education_form.form_fields.pluck(:id).map(&:to_s)
        continuing_education = all_params.slice(*ce_field_ids)
      end

      [ registration, scholarship, continuing_education ]
    end

    def visible_form_fields
      scope = @registration_form.form_fields

      person = current_user&.person
      if person
        # Always hide logged_out_only fields for logged-in users with known data
        known_identifiers = person_known_identifiers(person)
        if known_identifiers.any?
          known_ids = @registration_form.form_fields
                           .where(visibility: :logged_out_only, field_identifier: known_identifiers)
                           .ids
          scope = scope.where.not(id: known_ids) if known_ids.any?
        end

        # Hide logged_out_only headers when all their non-header fields are hidden
        logged_out_sections = @registration_form.form_fields.where(visibility: :logged_out_only)
                                  .where.not(answer_type: :group_header)
                                  .pluck(:section).uniq.compact
        logged_out_sections.each do |sect|
          section_field_ids = @registration_form.form_fields.where(section: sect, visibility: :logged_out_only)
                                  .where.not(answer_type: :group_header).ids
          if section_field_ids.any? && known_identifiers.any? && (section_field_ids - scope.where(id: section_field_ids).ids).any?
            remaining = scope.where(id: section_field_ids).ids
            if remaining.empty?
              scope = scope.where.not(section: sect, answer_type: :group_header, visibility: :logged_out_only)
            end
          end
        end

        if @registration_form.hide_answered_form_questions?
          answered_field_ids = []

          # One-time fields: hide if answered on ANY form submission for this person
          one_time_field_ids = @registration_form.form_fields.where(visibility: :answers_on_file, one_time: true)
                                   .where.not(answer_type: :group_header).ids
          if one_time_field_ids.any?
            answered_one_time = FormAnswer.joins(:form_submission)
                                         .where(form_submissions: { person_id: person.id })
                                         .where(form_field_id: one_time_field_ids)
                                         .where.not(submitted_answer: [ nil, "" ])
                                         .pluck(:form_field_id)
            answered_field_ids.concat(answered_one_time)
          end

          # Regular fields: hide if answered on a submission for this event
          event_submissions = FormSubmission.where(person: person, event_id: @event.id)
          if event_submissions.exists?
            regular_field_ids = @registration_form.form_fields.where(visibility: :answers_on_file, one_time: false)
                                     .where.not(answer_type: :group_header).ids
            if regular_field_ids.any?
              answered_regular = FormAnswer.where(form_submission: event_submissions)
                                          .where(form_field_id: regular_field_ids)
                                          .where.not(submitted_answer: [ nil, "" ])
                                          .pluck(:form_field_id)
              answered_field_ids.concat(answered_regular)
            end
          end

          answered_field_ids.uniq!
          if answered_field_ids.any?
            scope = scope.where.not(id: answered_field_ids)

            # Hide section headers when all their non-header fields are answered
            answered_sections = @registration_form.form_fields.where(id: answered_field_ids)
                                    .pluck(:section).uniq.compact
            answered_sections.each do |sect|
              section_field_ids = @registration_form.form_fields.where(section: sect, visibility: :answers_on_file)
                                      .where.not(answer_type: :group_header).ids
              if section_field_ids.any? && (section_field_ids - answered_field_ids).empty?
                scope = scope.where.not(section: sect, answer_type: :group_header, visibility: :answers_on_file)
              end
            end
          end
        end
      end

      if @event.cost_cents.to_i <= 0
        payment_field_ids = @registration_form.form_fields.where(field_identifier: "payment_method").ids
        if payment_field_ids.any?
          scope = scope.where.not(id: payment_field_ids)

          header = @registration_form.form_fields.find_by(answer_type: :group_header, name: "Payment Information")
          scope = scope.where.not(id: header.id) if header
        end
      end

      scope.reorder(position: :asc)
    end

    def person_known_identifiers(person)
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
      fields = visible_form_fields.to_a
      errors = FormAnswerValidator.call(fields, form_params)

      fields_by_identifier = fields.select { |f| f.field_identifier.present? }.index_by(&:field_identifier)
      confirm_field = fields_by_identifier["confirm_email"]
      email_field = fields_by_identifier["primary_email"]
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
