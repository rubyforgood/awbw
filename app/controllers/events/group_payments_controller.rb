module Events
  class GroupPaymentsController < ApplicationController
    skip_before_action :authenticate_user!, only: [ :new, :create, :show ]
    before_action :set_event
    before_action :set_form, only: [ :new, :create ]

    rescue_from ActionController::InvalidAuthenticityToken do
      flash[:alert] = "Your session has expired. Please try submitting the form again."
      redirect_to new_event_group_payment_path(@event)
    end

    def new
      authorize! :group_payment, to: :new?

      @form_fields = @form.form_fields.reorder(position: :asc)
      @event = @event.decorate

      @attendee_field = @form.form_fields.find_by(field_identifier: "group_payment_attendees")
    end

    def create
      authorize! :group_payment, to: :create?

      @form_params = params.dig(:group_payment, :form_fields)&.to_unsafe_h || {}

      @field_errors = validate_required_fields
      if @field_errors.any?
        @form_fields = @form.form_fields.reorder(position: :asc)
        @event = @event.decorate
        @attendee_field = @form.form_fields.find_by(field_identifier: "group_payment_attendees")
        render :new, status: :unprocessable_content
        return
      end

      result = EventRegistrationServices::GroupPayment.call(
        event: @event,
        form: @form,
        form_params: @form_params,
        person: current_user&.person
      )

      if result.success?
        redirect_to event_group_payment_path(@event, submission_id: result.form_submission.id),
                    notice: "Your group payment information has been submitted."
      else
        @form_fields = @form.form_fields.reorder(position: :asc)
        @event = @event.decorate
        @attendee_field = @form.form_fields.find_by(field_identifier: "group_payment_attendees")
        flash.now[:alert] = result.errors.join(", ")
        render :new, status: :unprocessable_content
      end
    end

    def show
      authorize! :group_payment, to: :show?

      @submission = FormSubmission.find(params[:submission_id])
      @form = @submission.form
      @form_fields = @form.form_fields.reorder(position: :asc)
      @responses = @submission.form_answers.index_by(&:form_field_id)
      @event = @event.decorate

      attendee_answer = @responses.values.find { |a|
        a.form_field&.field_identifier == "group_payment_attendees"
      }
      @attendees = parse_attendees(attendee_answer&.submitted_answer)
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end

    def set_form
      @form = @event.group_payment_form
      unless @form
        redirect_to event_path(@event), alert: "Group payment form is not available for this event."
      end
    end

    def validate_required_fields
      errors = {}
      visible_fields = @form.form_fields.reorder(position: :asc)

      visible_fields.find_each do |field|
        next if field.group_header?
        next if field.field_identifier == "group_payment_attendees"

        value = @form_params[field.id.to_s]

        if field.required && (value.blank? || (value.is_a?(Array) && value.reject(&:blank?).empty?))
          errors[field.id] = "can't be blank"
          next
        end

        next if value.blank?

        if field.number_integer? && value.to_s !~ /\A\d+\z/
          errors[field.id] = "must be a whole number"
        elsif field.field_identifier == "payer_email" && value.to_s !~ /\A[^@\s]+@[^@\s]+\z/
          errors[field.id] = "must be a valid email address"
        end
      end

      errors
    end

    def parse_attendees(json)
      return [] if json.blank?
      parsed = JSON.parse(json)
      parsed.is_a?(Array) ? parsed : []
    rescue JSON::ParserError
      []
    end
  end
end
