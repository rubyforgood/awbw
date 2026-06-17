module Events
  class BulkPaymentsController < ApplicationController
    skip_before_action :authenticate_user!, only: [ :new, :create, :show, :ticket ]
    before_action :set_event, only: [ :new, :create, :show ]
    before_action :set_form, only: [ :new, :create ]

    rescue_from ActionController::InvalidAuthenticityToken do
      flash[:alert] = "Your session has expired. Please try submitting the form again."
      redirect_to new_event_bulk_payment_path(@event)
    end

    def new
      authorize! :bulk_payment, to: :new?

      @form_fields = visible_form_fields
      @event = @event.decorate

      @attendee_field = @form.form_fields.find_by(field_identifier: "bulk_payment_attendees")
    end

    def create
      authorize! :bulk_payment, to: :create?

      @form_params = params.dig(:bulk_payment, :form_fields)&.to_unsafe_h || {}

      @field_errors = validate_required_fields
      if @field_errors.any?
        @form_fields = visible_form_fields
        @event = @event.decorate
        @attendee_field = @form.form_fields.find_by(field_identifier: "bulk_payment_attendees")
        render :new, status: :unprocessable_content
        return
      end

      result = EventRegistrationServices::BulkPayment.call(
        event: @event,
        form: @form,
        form_params: @form_params,
        person: current_user&.person
      )

      if result.success?
        if @event.cost_cents.to_i > 0 && credit_card_payment?(@form_params)
          checkout_session = create_stripe_checkout_session(result.form_submission)
          redirect_to checkout_session.url, allow_other_host: true, status: :see_other
        else
          redirect_to bulk_payment_ticket_path(result.form_submission.slug),
                      notice: "Your bulk payment information has been submitted."
        end
      else
        @form_fields = visible_form_fields
        @event = @event.decorate
        @attendee_field = @form.form_fields.find_by(field_identifier: "bulk_payment_attendees")
        flash.now[:alert] = result.errors.join(", ")
        render :new, status: :unprocessable_content
      end
    end

    def show
      authorize! :bulk_payment, to: :show?

      @submission = FormSubmission.find(params[:submission_id])
      @payment = @submission.payment
      @event = @event.decorate
    end

    # Public, slug-based ticket for the payer. Shows the event details, the
    # registrants they paid for, and the submitted form — but none of the
    # per-person admin actions found on the bulk payments dashboard.
    def ticket
      authorize! :bulk_payment, to: :ticket?

      @submission = FormSubmission.bulk_payment.find_by!(slug: params[:slug])
      @payment = @submission.payment
      @event = @submission.event.decorate
    end

    private

    def visible_form_fields
      scope = @form.form_fields.reorder(position: :asc)

      if current_user
        logged_out_only_ids = scope.where(visibility: :logged_out_only).ids
        scope = scope.where.not(id: logged_out_only_ids) if logged_out_only_ids.any?
      end

      scope
    end

    def set_event
      @event = Event.find(params[:event_id])
    end

    def set_form
      @form = @event.bulk_payment_form
      unless @form
        redirect_to event_path(@event), alert: "Bulk payment form is not available for this event."
      end
    end

    def validate_required_fields
      # The nested attendees field is validated separately, so exclude it here.
      fields = visible_form_fields.reject { |field| field.field_identifier == "bulk_payment_attendees" }
      FormAnswerValidator.call(fields, @form_params)
    end

    def credit_card_payment?(form_params)
      payment_method_field = @form.form_fields.find_by(field_identifier: "payment_method")
      return false unless payment_method_field

      form_params[payment_method_field.id.to_s]&.downcase == FormBuilderService::PAYMENT_METHOD_PAY_NOW.downcase
    end

    def create_stripe_checkout_session(submission)
      person = submission.person
      unit_amount = @event.cost_cents

      attendees_field = @form.form_fields.find_by(field_identifier: "number_of_attendees")
      qty = attendees_field ? @form_params[attendees_field.id.to_s].to_i : 1
      qty = 1 if qty < 1

      metadata = { form_submission_id: submission.id, event_id: @event.id }

      attendees_field = @form.form_fields.find_by(field_identifier: "bulk_payment_attendees")
      if attendees_field
        attendees_json = @form_params[attendees_field.id.to_s]
        metadata[:attendees] = attendees_json if attendees_json.present?
      end

      person.set_payment_processor :stripe

      person.payment_processor.checkout(
        mode: "payment",
        metadata: metadata,
        payment_intent_data: { metadata: metadata, description: "Training Fee: #{@event.title}" },
        line_items: [ {
          price_data: {
            currency: "usd",
            product_data: { name: "Bulk Payment (#{qty} attendees): #{@event.title}" },
            unit_amount: unit_amount
          },
          quantity: qty
        } ],
        success_url: bulk_payment_ticket_url(submission.slug, checkout: "success"),
        cancel_url: bulk_payment_ticket_url(submission.slug, checkout: "cancelled")
      )
    end
  end
end
