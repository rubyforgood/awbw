module Events
  class PublicFormsController < ApplicationController
    # Each public form lane maps to a presentation + behavior. `mode`:
    #   :register   — render the registration form (+ scholarship section), create/update an EventRegistration
    #   :addon      — render a single role form, attach answers to an EXISTING registration and flag it
    #   :submission — render a single role form, record a standalone FormSubmission
    LANES = {
      "registration" => { heading: "Registration", mode: :register, scholarship: false },
      "scholarship" => { heading: "Scholarship application", mode: :register, scholarship: true },
      "scholarship_questions" => { heading: "Scholarship application", mode: :addon, role: "scholarship", flag: :scholarship_requested },
      "ce_questions" => { heading: "Continuing education credit", mode: :addon, role: "ce_credit", flag: :ce_credit_requested },
      "general" => { heading: "General", mode: :submission, role: "general" }
    }.freeze

    skip_before_action :authenticate_user!, only: [ :new, :create, :show ]
    before_action :set_event
    before_action :ensure_registerable, only: [ :new, :create ]

    rescue_from ActionController::InvalidAuthenticityToken do
      flash[:alert] = "Your session has expired. Please try submitting the form again."
      redirect_to public_form_new_path
    end

    def new
      authorize! :public_form, to: :new?
      return new_standalone if standalone_lane?

      @form = registration_form
      unless @form
        redirect_to event_path(@event), alert: "Registration form is not available for this event."
        return
      end

      @form_fields = visible_form_fields
      @scholarship = lane[:scholarship]
      @scholarship_form = @event.scholarship_form if @scholarship
      @event = @event.decorate
    end

    def create
      authorize! :public_form, to: :create?
      return create_standalone if standalone_lane?

      if params[:public_registration][:website_url].present?
        redirect_to public_form_new_path
        return
      end

      @form = registration_form
      @scholarship = lane[:scholarship]
      @scholarship_form = @event.scholarship_form if @scholarship

      all_params = params.dig(:public_registration, :form_fields)&.to_unsafe_h || {}
      registration_params, scholarship_params = split_form_params(all_params)

      @field_errors = validate_required_fields(registration_params)
      if @scholarship_form
        scholarship_fields = @scholarship_form.form_fields.where.not(answer_type: :group_header).to_a
        @field_errors = @field_errors.merge(FormAnswerValidator.call(scholarship_fields, scholarship_params))
      end
      if @field_errors.any?
        @form_fields = visible_form_fields
        @event = @event.decorate
        render :new, status: :unprocessable_content
        return
      end

      Current.source = "public_registration"

      result = EventRegistrationServices::PublicRegistration.call(
        event: @event,
        form: @form,
        form_params: registration_params,
        scholarship_requested: @scholarship,
        person: current_user&.person
      )

      if result.success?
        registration = result.event_registration

        if !registration.scholarship_requested? && @event.cost_cents.to_i > 0 && credit_card_payment?(registration_params)
          checkout_session = create_stripe_checkout_session(registration, result.form_submission)
          redirect_to checkout_session.url, allow_other_host: true, status: :see_other
        else
          redirect_to registration_ticket_path(registration.slug),
                      notice: "You have been successfully registered!"
        end
      else
        @form_fields = visible_form_fields
        @event = @event.decorate
        flash.now[:alert] = result.errors.join(", ")
        render :new, status: :unprocessable_content
      end
    end

    def show
      authorize! :public_form, to: :show?

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

      @form_fields = visible_form_fields
      @responses = @form_submission.form_answers.index_by(&:form_field_id)
      @event = @event.decorate
    end

    private

    def credit_card_payment?(form_params)
      payment_method_field = @form.form_fields.find_by(field_identifier: "payment_method")
      return false unless payment_method_field

      form_params[payment_method_field.id.to_s]&.downcase == FormBuilderService::PAYMENT_METHOD_PAY_NOW.downcase
    end

    def create_stripe_checkout_session(registration, submission = nil)
      person = registration.registrant
      amount = @event.cost_cents

      metadata = { event_registration_id: registration.id, event_id: @event.id }
      metadata[:form_submission_id] = submission.id if submission

      person.set_payment_processor :stripe

      person.payment_processor.checkout(
        mode: "payment",
        metadata: metadata,
        payment_intent_data: { metadata: metadata },
        line_items: [ {
          price_data: {
            currency: "usd",
            product_data: { name: "Registration: #{@event.title}" },
            unit_amount: amount
          },
          quantity: 1
        } ],
        success_url: registration_ticket_url(registration.slug, checkout: "success"),
        cancel_url: registration_ticket_url(registration.slug, checkout: "cancelled")
      )
    end

    def set_event
      @event = Event.find(params[:event_id])
    end

    def registration_form
      @event.registration_form
    end

    def form_role
      LANES.key?(params[:form_role]) ? params[:form_role] : "registration"
    end
    helper_method :form_role

    def lane
      LANES.fetch(form_role)
    end

    def standalone_lane?
      lane[:mode] != :register
    end

    def public_form_new_path
      new_event_form_path(@event, form_role, reg: params[:reg].presence)
    end

    def public_form_submit_path
      event_form_path(@event, form_role, reg: params[:reg].presence)
    end

    def public_form_heading
      lane.fetch(:heading)
    end
    helper_method :public_form_new_path, :public_form_submit_path, :public_form_heading

    # ----- standalone lanes (:addon, :submission) -----

    def new_standalone
      @form = @event.public_send("#{lane[:role]}_form")
      unless @form
        redirect_to event_path(@event), alert: "This form is not available for this event."
        return
      end

      if lane[:mode] == :addon && resolve_registration.nil?
        redirect_to event_path(@event), alert: "Please register for this event first."
        return
      end

      @form_fields = @form.form_fields.reorder(position: :asc)
      @event = @event.decorate
      render :standalone
    end

    def create_standalone
      if params.dig(:public_registration, :website_url).present?
        redirect_to public_form_new_path
        return
      end

      @form = @event.public_send("#{lane[:role]}_form")
      registration = resolve_registration if lane[:mode] == :addon
      person = registration&.registrant || current_user&.person

      if lane[:mode] == :addon && registration.nil?
        redirect_to event_path(@event), alert: "Please register for this event first."
        return
      end
      if person.nil?
        redirect_to event_path(@event), alert: "Please sign in to submit this form."
        return
      end

      answers = params.dig(:public_registration, :form_fields)&.to_unsafe_h || {}
      fields = @form.form_fields.where.not(answer_type: :group_header).to_a
      @field_errors = FormAnswerValidator.call(fields, answers)
      if @field_errors.any?
        @form_fields = @form.form_fields.reorder(position: :asc)
        @event = @event.decorate
        render :standalone, status: :unprocessable_content
        return
      end

      record_form_submission(person, @form, answers)
      registration&.update!(lane[:flag] => true) if lane[:flag]

      if registration
        redirect_to registration_ticket_path(registration.slug), notice: "Your responses have been submitted."
      else
        redirect_to event_path(@event), notice: "Your responses have been submitted."
      end
    end

    def resolve_registration
      @resolve_registration ||= if params[:reg].present?
        @event.event_registrations.find_by(slug: params[:reg])
      elsif current_user&.person
        @event.active_registration_for(current_user.person)
      end
    end

    def record_form_submission(person, form, answers)
      submission = FormSubmission.find_or_create_by!(person: person, form: form, role: lane[:role])
      answers.each do |field_id, raw_value|
        field = form.form_fields.find_by(id: field_id)
        next unless field
        next if field.group_header?

        text = raw_value.is_a?(Array) ? raw_value.reject(&:blank?).join(", ") : raw_value.to_s
        record = submission.form_answers.find_or_initialize_by(form_field: field)
        record.update!(submitted_answer: text, question_name_when_answered: field.name)
      end
      submission
    end

    def split_form_params(all_params)
      reg_field_ids = @form.form_fields.pluck(:id).map(&:to_s)
      registration = all_params.slice(*reg_field_ids)

      scholarship = {}
      if @scholarship_form
        scholarship_field_ids = @scholarship_form.form_fields.pluck(:id).map(&:to_s)
        scholarship = all_params.slice(*scholarship_field_ids)
      end

      [ registration, scholarship ]
    end

    def visible_form_fields
      scope = @form.form_fields

      person = current_user&.person
      if person
        # Always hide logged_out_only fields for logged-in users with known data
        known_identifiers = person_known_identifiers(person)
        if known_identifiers.any?
          known_ids = @form.form_fields
                           .where(visibility: :logged_out_only, field_identifier: known_identifiers)
                           .ids
          scope = scope.where.not(id: known_ids) if known_ids.any?
        end

        # Hide logged_out_only headers when all their non-header fields are hidden
        logged_out_sections = @form.form_fields.where(visibility: :logged_out_only)
                                  .where.not(answer_type: :group_header)
                                  .pluck(:section).uniq.compact
        logged_out_sections.each do |sect|
          section_field_ids = @form.form_fields.where(section: sect, visibility: :logged_out_only)
                                  .where.not(answer_type: :group_header).ids
          if section_field_ids.any? && known_identifiers.any? && (section_field_ids - scope.where(id: section_field_ids).ids).any?
            remaining = scope.where(id: section_field_ids).ids
            if remaining.empty?
              scope = scope.where.not(section: sect, answer_type: :group_header, visibility: :logged_out_only)
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
                                         .where.not(submitted_answer: [ nil, "" ])
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
                                          .where.not(submitted_answer: [ nil, "" ])
                                          .pluck(:form_field_id)
              answered_field_ids.concat(answered_regular)
            end
          end

          answered_field_ids.uniq!
          if answered_field_ids.any?
            scope = scope.where.not(id: answered_field_ids)

            # Hide section headers when all their non-header fields are answered
            answered_sections = @form.form_fields.where(id: answered_field_ids)
                                    .pluck(:section).uniq.compact
            answered_sections.each do |sect|
              section_field_ids = @form.form_fields.where(section: sect, visibility: :answers_on_file)
                                      .where.not(answer_type: :group_header).ids
              if section_field_ids.any? && (section_field_ids - answered_field_ids).empty?
                scope = scope.where.not(section: sect, answer_type: :group_header, visibility: :answers_on_file)
              end
            end
          end
        end
      end

      if @event.cost_cents.to_i <= 0
        payment_field_ids = @form.form_fields.where(field_identifier: "payment_method").ids
        if payment_field_ids.any?
          scope = scope.where.not(id: payment_field_ids)

          header = @form.form_fields.find_by(answer_type: :group_header, name: "Payment Information")
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
