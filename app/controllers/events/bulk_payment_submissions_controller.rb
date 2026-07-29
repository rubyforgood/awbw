module Events
  class BulkPaymentSubmissionsController < ApplicationController
    skip_before_action :authenticate_user!, only: [ :new, :create, :show, :ticket, :resend_confirmation, :edit, :update ]
    before_action :set_event, only: [ :new, :create, :show ]
    before_action :set_form, only: [ :new, :create ]

    rescue_from ActionController::InvalidAuthenticityToken do
      flash[:alert] = "Your session has expired. Please try submitting the form again."
      redirect_to new_event_bulk_payment_path(@event)
    end

    def new
      authorize! :form_submission

      @form_fields = visible_form_fields
      @event = @event.decorate

      @attendee_field = @form.form_fields.find_by(field_identifier: "bulk_payment_attendees")
    end

    def create
      authorize! :form_submission

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
                      notice: "Your payment information has been submitted."
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
      slug = params[:slug]
      if slug.present?
        @submission = FormSubmission.bulk_payment
                                    .find_by!(slug: slug, event_id: @event.id)
      else
        @submission = FormSubmission.bulk_payment.find_by!(id: params[:submission_id], event_id: @event.id)
      end
      authorize! @submission, context: { slug: slug }

      @event = @event.decorate
    end

    def ticket
      @submission = FormSubmission.bulk_payment.find_by!(slug: params[:slug])
      authorize! @submission, context: { slug: params[:slug] }

      @payment = @submission.payment
      event = @submission.event
      @event = event.decorate
      # Per-attendee coverage is admin-only: a payer would be alarmed to see a
      # balance "due" before staff have allocated a payment that's already landed.
      @attendee_statuses = attendee_payment_statuses(event) if allowed_to?(:dashboard?, event)
    end

    # Public, slug-based editor for the attendee ("member") list on a submission.
    # The payer edits their own submission here; admins are routed to the same
    # page so changes happen in one place. Attendees already matched ("connected")
    # to an event registrant render read-only, but can still be removed.
    def edit
      @submission = FormSubmission.bulk_payment.find_by!(slug: params[:slug])
      authorize! @submission, to: :edit?, context: { slug: params[:slug] }

      event = @submission.event
      @attendee_matches = @submission.decorate.matched_attendees(active_event_registrations(event))
      @event = event.decorate
    end

    def update
      @submission = FormSubmission.bulk_payment.find_by!(slug: params[:slug])
      authorize! @submission, to: :update?, context: { slug: params[:slug] }

      # Locked rows are rendered read-only but still submit their (unchanged)
      # values, so writing the whole submitted set preserves connected attendees,
      # applies edits to unmatched rows, and honors additions/removals.
      if @submission.update_bulk_payment_attendees(submitted_attendees)
        send_update_notifications(@submission)
        redirect_to bulk_payment_ticket_path(@submission.slug), notice: "Attendees updated."
      else
        redirect_to bulk_payment_ticket_path(@submission.slug),
                    alert: "This submission can't have its attendees edited."
      end
    end

    def resend_confirmation
      @submission = FormSubmission.bulk_payment.find_by!(slug: params[:slug])
      authorize! @submission, to: :show?, context: { slug: params[:slug] }

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

    def active_event_registrations(event)
      event.event_registrations.active.includes(:registrant)
    end

    # For each listed attendee (in order), the coverage of the registration they
    # match: :paid (fully allocated), :due (with the remaining cents), or
    # :unregistered (no matching active registration). Aligned to
    # bulk_payment_attendees by index.
    def attendee_payment_statuses(event)
      registrations = active_event_registrations(event)
      allocated = Allocation
                    .where(allocatable_type: "EventRegistration", allocatable_id: registrations.ids)
                    .group(:allocatable_id).sum(:amount)
      cost = event.cost_cents.to_i

      @submission.decorate.matched_attendees(registrations).map do |attendee|
        regs = attendee[:matches]
        next { state: :unregistered } if regs.empty?

        remaining = regs.sum { |reg| [ cost - allocated.fetch(reg.id, 0), 0 ].max }
        remaining.zero? ? { state: :paid } : { state: :due, due_cents: remaining }
      end
    end

    # After an attendee-list edit, re-confirm to the payer and FYI staff — both as
    # "updated" variants so they read as a change, not a fresh submission.
    def send_update_notifications(submission)
      payer_email = submission.person.preferred_email.presence ||
                    submission.answers_by_identifier["payer_email"]&.strip
      if payer_email.present?
        NotificationServices::CreateNotification.call(
          noticeable: submission,
          kind: :bulk_payment_confirmation_updated,
          recipient_role: :person,
          recipient_email: payer_email,
          notification_type: 0
        )
      end

      NotificationServices::CreateNotification.call(
        noticeable: submission,
        kind: :bulk_payment_confirmation_updated_fyi,
        recipient_role: :admin,
        recipient_email: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org"),
        notification_type: 0
      )
    end

    # Parses the serialized attendee JSON posted from the edit form into a clean
    # array of stripped { first_name, last_name, email } hashes, dropping any row
    # left entirely blank (mirrors the Stimulus serializer).
    def submitted_attendees
      raw = params.dig(:bulk_payment, :attendees_json)
      return [] if raw.blank?

      parsed = JSON.parse(raw)
      return [] unless parsed.is_a?(Array)

      parsed.filter_map do |attendee|
        next unless attendee.is_a?(Hash)

        first = attendee["first_name"].to_s.strip
        last = attendee["last_name"].to_s.strip
        email = attendee["email"].to_s.strip
        next if first.blank? && last.blank? && email.blank?

        { "first_name" => first, "last_name" => last, "email" => email }
      end
    rescue JSON::ParserError
      []
    end

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
        redirect_to event_path(@event), alert: "#{Form::BULK_PAYMENT_PUBLIC_NAME} form is not available for this event."
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
            product_data: { name: "#{Form::BULK_PAYMENT_PUBLIC_NAME} (#{qty} attendees): #{@event.title}" },
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
