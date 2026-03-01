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

      @form_fields = @form.form_fields.where(status: :active).reorder(position: :asc)
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
        @form_fields = @form.form_fields.where(status: :active).reorder(position: :asc)
        @event = @event.decorate
        render :new, status: :unprocessable_content
        return
      end

      Current.source = "public_registration"

      result = EventRegistrationServices::PublicRegistration.call(
        event: @event,
        form: @form,
        form_params: form_params
      )

      if result.success?
        redirect_to registration_ticket_path(result.event_registration.slug),
                    notice: "You have been successfully registered!"
      else
        @form_fields = @form.form_fields.where(status: :active).reorder(position: :asc)
        @event = @event.decorate
        flash.now[:alert] = result.errors.join(", ")
        render :new, status: :unprocessable_content
      end
    end

    def show
      authorize! :public_registration, to: :show?

      registration = EventRegistration.find_by!(slug: params[:reg], event_id: @event.id)

      @form = registration_form
      unless @form
        redirect_to event_path(@event), alert: "Registration form not found."
        return
      end

      @person_form = @form.person_forms.find_by(person: registration.registrant)
      unless @person_form
        redirect_to event_path(@event), alert: "No registration form submission found."
        return
      end

      @form_fields = @form.form_fields.where(status: :active).reorder(position: :asc)
      @responses = @person_form.person_form_form_fields.index_by(&:form_field_id)
      @event = @event.decorate
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end

    def registration_form
      @event.forms.find_by(name: EventRegistrationFormBuilder::FORM_NAME)
    end

    def ensure_registerable
      unless @event.registerable?
        redirect_to event_path(@event), alert: "Registration is closed for this event."
      end
    end

    def validate_required_fields(form_params)
      errors = {}
      fields = @form.form_fields.where(status: :active)
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
