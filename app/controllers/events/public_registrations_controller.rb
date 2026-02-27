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

      result = EventRegistrationServices::PublicRegistration.call(
        event: @event,
        form: @form,
        form_params: form_params
      )

      if result.success?
        redirect_to event_registration_path(result.event_registration),
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

      @form = registration_form
      unless @form
        redirect_to event_path(@event), alert: "Registration form not found."
        return
      end


      @person_form = @form.person_forms.find_by(person: params[:person_id])
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
      @form.form_fields.where(status: :active).find_each do |field|
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
      errors
    end
  end
end
