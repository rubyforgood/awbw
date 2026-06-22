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
      @scholarship_form = @event.scholarship_form if @scholarship
      @event = @event.decorate
    end

    def create
      authorize! :public_registration, to: :create?

      if params[:public_registration][:website_url].present?
        redirect_to new_event_public_registration_path(@event)
        return
      end

      @form = registration_form
      @scholarship = scholarship_mode?
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
        flash.now[:alert] = "Your registration is not complete yet. Scroll down to check for any errors or missing information."
        render :new, status: :unprocessable_content
        return
      end

      Current.source = "public_registration"

      result = EventRegistrationServices::PublicRegistration.call(
        event: @event,
        form: @form,
        form_params: registration_params,
        scholarship_requested: @scholarship,
        person: current_user&.person,
        scholarship_form: @scholarship_form,
        scholarship_params: scholarship_params
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

      @form = registration_form
      unless @form
        redirect_to event_path(@event), alert: "Registration form not found."
        return
      end

      # A specific submission can be requested by id (a registrant may have more
      # than one); scope it to this form and person so the id can't reach another
      # person's submission. Otherwise show their first submission for the form.
      submissions = @form.form_submissions.where(person: person)
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
        success_url: registration_ticket_url(registration.slug, checkout: "success"),
        cancel_url: registration_ticket_url(registration.slug, checkout: "cancelled")
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

    # Surface the separate scholarship-form application (its own role: "scholarship"
    # submission) on the view-submission page when the registrant filled it out.
    # Only set when answers are actually on file so the view renders nothing for
    # plain registrations.
    def load_scholarship_submission(person)
      scholarship_form = @event.scholarship_form
      return unless scholarship_form

      submission = scholarship_form.form_submissions.find_by(person: person, role: "scholarship")
      return unless submission&.form_answers&.exists?

      @scholarship_submission = submission
      @scholarship_form = scholarship_form
      @scholarship_fields = scholarship_form.form_fields.reorder(position: :asc)
      @scholarship_responses = submission.form_answers.index_by(&:form_field_id)
    end

    def scholarship_mode?
      params[:scholarship_requested] == "true"
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
        scope = hide_logged_out_only_fields(scope)

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

          # Regular fields: hide if answered on a submission for this event
          event_submissions = FormSubmission.where(person: person, event_id: @event.id)
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

    # `logged_out_only` fields are asked only of logged-out registrants — a
    # signed-in registrant manages this data on their profile, and whatever we
    # already have is backfilled onto the submission by PersonKnownFields. So hide
    # the whole set for signed-in users regardless of what's on file, matching the
    # bulk-payment form's rule.
    #
    # Temporary exception: the Organization Information fields (`agency_*`) stay
    # visible until we backfill them from the person's affiliations. We keep their
    # section header too, and drop every other logged_out_only header once nothing
    # under it survives (walking in position order so headers that share a DB
    # `section` with the org fields are handled individually).
    ORG_FIELD_PREFIX = "agency_".freeze

    def hide_logged_out_only_fields(scope)
      ordered = @form.form_fields.where(visibility: :logged_out_only).reorder(position: :asc).to_a
      return scope if ordered.empty?

      hidden_ids = []
      pending_header = nil
      group_kept = false

      drop_empty_header = -> { hidden_ids << pending_header.id if pending_header && !group_kept }

      ordered.each do |field|
        if field.group_header?
          drop_empty_header.call
          pending_header = field
          group_kept = false
        elsif field.field_identifier.to_s.start_with?(ORG_FIELD_PREFIX)
          group_kept = true
        else
          hidden_ids << field.id
        end
      end
      drop_empty_header.call

      hidden_ids.any? ? scope.where.not(id: hidden_ids) : scope
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
