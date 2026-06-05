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
        registration = result.event_registration

        if !registration.scholarship_requested? && @event.cost_cents.to_i > 0 && credit_card_payment?(form_params)
          checkout_session = create_stripe_checkout_session(registration, form_params)
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

      @person_form = @form.person_forms.find_by(person: person)
      unless @person_form
        redirect_to event_path(@event), alert: "No registration form submission found."
        return
      end

      @form_fields = if registration&.scholarship_requested?
        @form.form_fields.where(status: :active).where.not(field_group: "payment").reorder(position: :asc)
      else
        @form.form_fields.where(status: :active).where.not(field_group: "scholarship").reorder(position: :asc)
      end
      @responses = @person_form.person_form_form_fields.index_by(&:form_field_id)
      @event = @event.decorate
    end

    private

    def credit_card_payment?(form_params)
      payment_method_field = @form.form_fields.find_by(field_key: "payment_method")
      return false unless payment_method_field

      form_params[payment_method_field.id.to_s] == "Credit Card"
    end

    def number_of_attendees(form_params)
      attendees_field = @form.form_fields.find_by(field_key: "number_of_attendees")
      return 1 unless attendees_field

      form_params[attendees_field.id.to_s].to_i
    end

    def create_stripe_checkout_session(registration, form_params)
      person = registration.registrant
      attendees = number_of_attendees(form_params)
      amount = @event.cost_cents * attendees

      person.set_payment_processor :stripe

      person.payment_processor.checkout(
        mode: "payment",
        metadata: { event_registration_id: registration.id },
        payment_intent_data: {
          metadata: { event_registration_id: registration.id }
        },
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

    def scholarship_mode?
      params[:scholarship_requested] == "true"
    end

    def visible_form_fields
      scope = @form.form_fields.where(status: :active)
      if scholarship_mode?
        scope = scope.where.not(field_group: "payment")
      else
        scope = scope.where.not(field_group: "scholarship")
      end
      scope.reorder(position: :asc)
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
        elsif field.field_key&.match?(/email(?!_type)/) && value.to_s !~ /\A[^@\s]+@[^@\s]+\z/
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
