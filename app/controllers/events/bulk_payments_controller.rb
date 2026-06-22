module Events
  class BulkPaymentsController < ApplicationController
    skip_before_action :authenticate_user!, only: [ :new, :create, :show, :ticket, :resend_confirmation ]
    before_action :set_event, only: [ :new, :create, :show ]
    before_action :set_form, only: [ :new, :create ]

    rescue_from ActionController::InvalidAuthenticityToken do
      flash[:alert] = "Your session has expired. Please try submitting the form again."
      redirect_to new_event_bulk_payment_path(@event)
    end

    def new
      authorize! :bulk_payment, to: :new?

      set_field_variables
      @event = @event.decorate
    end

    def create
      authorize! :bulk_payment, to: :create?

      @form_params = params.dig(:bulk_payment, :form_fields)&.to_unsafe_h || {}

      @field_errors = validate_required_fields
      if @field_errors.any?
        set_field_variables
        @event = @event.decorate
        render :new, status: :unprocessable_content
        return
      end

      result = EventRegistrationServices::BulkPayment.call(
        event: @event,
        form: @form,
        form_params: @form_params,
        # On-behalf mode finds/creates the payer from the form rather than tying
        # the submission to the admin filling it out.
        person: registration_person,
        send_confirmation: !on_behalf?
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
        set_field_variables
        @event = @event.decorate
        flash.now[:alert] = result.errors.join(", ")
        render :new, status: :unprocessable_content
      end
    end

    # View of the submitted bulk payment form, rendering the same partial either
    # way. Mirrors PublicRegistrations#show: the payer reaches it publicly by slug
    # (?reg=), while admins (e.g. from the dashboard, including legacy submissions
    # with no slug) reach it by id (?submission_id=).
    def show
      if params[:reg].present?
        authorize! :bulk_payment, to: :show?
        # where.not(slug: nil) keeps a blank reg from matching a slugless record.
        @submission = FormSubmission.bulk_payment.where.not(slug: nil)
                                    .find_by!(slug: params[:reg], event_id: @event.id)
      else
        @submission = FormSubmission.bulk_payment.find_by!(id: params[:submission_id], event_id: @event.id)
        authorize! @submission, to: :show?
      end

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

    # Re-sends the payer their bulk payment confirmation email (the one carrying
    # the ticket link). Reachable by the payer from the ticket.
    def resend_confirmation
      authorize! :bulk_payment, to: :show?

      @submission = FormSubmission.bulk_payment.find_by!(slug: params[:slug])
      payer_email = @submission.person.preferred_email.presence ||
                    @submission.answers_by_identifier["payer_email"]&.strip

      if payer_email.present?
        NotificationServices::CreateNotification.call(
          noticeable: @submission,
          kind: :bulk_payment_confirmation,
          recipient_role: :person,
          recipient_email: payer_email,
          notification_type: 0
        )
        redirect_to bulk_payment_ticket_path(@submission.slug), notice: "Confirmation email sent."
      else
        redirect_to bulk_payment_ticket_path(@submission.slug),
                    alert: "No email address on file to send the confirmation to."
      end
    end

    private

    # An admin (or event manager) submitting a bulk payment for someone else:
    # only honored for users who can manage the event, so a guest can't suppress
    # the payer's confirmation email.
    def on_behalf?
      return false unless ActiveModel::Type::Boolean.new.cast(params[:on_behalf])
      allowed_to?(:dashboard?, @event)
    end
    helper_method :on_behalf?

    # The person the form is being filled out for. In on-behalf mode there's no
    # logged-in payer, so we treat it as a fresh (logged-out) submission and let
    # the service find/create the payer from the form.
    def registration_person
      on_behalf? ? nil : current_user&.person
    end

    # Builds @form_fields for the form. Admins always get the full logged-out
    # field set so they can pay on a not-logged-in person's behalf; the payer
    # fields normally hidden for the logged-in admin are flagged "behalf-only"
    # and revealed client-side when "on behalf" is checked.
    def set_field_variables
      @attendee_field = @form.form_fields.find_by(field_identifier: "bulk_payment_attendees")

      unless allowed_to?(:dashboard?, @event)
        @form_fields = visible_form_fields
        @behalf_only_field_ids = []
        return
      end

      logged_in_ids = visible_form_fields(include_logged_out_only: false).ids
      @form_fields = visible_form_fields(include_logged_out_only: true)
      @behalf_only_field_ids = @form_fields.ids - logged_in_ids
    end

    def visible_form_fields(include_logged_out_only: current_user.nil?)
      scope = @form.form_fields.reorder(position: :asc)
      return scope if include_logged_out_only

      logged_out_only_ids = scope.where(visibility: :logged_out_only).ids
      logged_out_only_ids.any? ? scope.where.not(id: logged_out_only_ids) : scope
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
      # In on-behalf mode the payer fields are shown and must be validated even
      # though they're hidden for a logged-in admin by default.
      visible_fields = on_behalf? ? visible_form_fields(include_logged_out_only: true) : visible_form_fields
      # The nested attendees field is validated separately, so exclude it here.
      fields = visible_fields.reject { |field| field.field_identifier == "bulk_payment_attendees" }
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
