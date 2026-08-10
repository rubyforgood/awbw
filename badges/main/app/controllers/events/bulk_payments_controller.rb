module Events
  class BulkPaymentsController < ApplicationController
    before_action :set_event

    def index
      authorize! @event

      @event_registrations = @event.event_registrations.active.includes(:registrant)
      @submissions = @event.form_submissions
                           .where(role: "bulk_payment")
                           .includes(:person, form_answers: :form_field, payment: :allocations)
                           .order(created_at: :desc)
      @allocated_by_registration = allocated_cents_by_registration(@event_registrations)
      @event = @event.decorate
    end

    def create
      authorize! @event
      @event_registrations = @event.event_registrations.active.includes(:registrant)
      @allocated_by_registration = allocated_cents_by_registration(@event_registrations)

      submission = @event.form_submissions.find(params[:submission_id])
      payment_type = params[:payment_type]

      @event = @event.decorate

      unless %w[CashPayment CheckPayment].include?(payment_type)
        flash.now[:alert] = "Invalid payment type"
        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to bulk_payments_event_path(@event), alert: "Invalid payment type" }
        end
        return
      end

      payment = submission.build_payment(
        amount_cents: (params[:amount_dollars].to_d * 100).to_i,
        currency: params[:currency].presence || "usd",
        type: payment_type,
        check_number: params[:check_number].presence,
        memo: params[:memo].presence
      )
      payment.payer_sgid = params[:payer_sgid]
      payment.additional_designation_sgid = params[:additional_designation_sgid]

      if payment.save
        @payment = payment
        @submission = submission.decorate
        flash.now[:notice] = "Payment recorded"
      else
        flash.now[:alert] = payment.errors.full_messages.to_sentence
      end

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to bulk_payments_event_path(@event), notice: flash.now[:alert] || "Payment recorded" }
      end
    end

    def allocate
      authorize! @event
      @event = @event.decorate
      payment = Payment.find(params[:payment_id])
      event_registration = EventRegistration.find_by(id: params[:event_registration_id])
      unless event_registration
        flash.now[:alert] = "Please select a registrant"
        assign_allocation_card_data(payment)
        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to bulk_payments_event_path(@event), alert: "Please select a registrant" }
        end
        return
      end
      amount_cents = (params[:amount_dollars].to_d * 100).to_i

      if amount_cents <= 0
        flash.now[:alert] = "Amount must be greater than $0.00"
      elsif amount_cents > (payment.amount_cents_remaining || 0)
        flash.now[:alert] = "Amount exceeds remaining balance"
      else
        allocation = Allocation.new(source: payment, allocatable: event_registration, amount: amount_cents)
        if allocation.save
          flash.now[:notice] = "Allocation successful"
        else
          flash.now[:alert] = allocation.errors.full_messages.to_sentence
        end
      end

      assign_allocation_card_data(payment)

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to bulk_payments_event_path(@event), notice: flash.now[:alert] || "Allocation successful" }
      end
    end

    def link
      authorize! @event
      @event = @event.decorate

      submission = @event.form_submissions.find(params[:submission_id])
      event_registration = EventRegistration.find_by(id: params[:event_registration_id])

      if event_registration
        submission.link_registration!(event_registration.id)
        flash.now[:notice] = "Linked #{event_registration.registrant.name}."
      else
        flash.now[:alert] = "Registration not found."
      end

      assign_bulk_payment_card_data(submission)

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to bulk_payments_event_path(@event), notice: flash.now[:notice] || flash.now[:alert] }
      end
    end

    def unlink
      authorize! @event
      @event = @event.decorate

      submission = @event.form_submissions.find(params[:submission_id])
      event_registration = EventRegistration.find_by(id: params[:event_registration_id])

      if event_registration
        submission.unlink_registration!(event_registration.id)
        flash.now[:notice] = "Unlinked #{event_registration.registrant.name}."
      else
        flash.now[:alert] = "Registration not found."
      end

      assign_bulk_payment_card_data(submission)

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to bulk_payments_event_path(@event), notice: flash.now[:notice] || flash.now[:alert] }
      end
    end

    private

    def set_event
      @event = Event.find(params[:id])
    end

    def assign_allocation_card_data(payment)
      @payment = payment.reload
      @submission = @payment.form_submission
      @event_registrations = @event.event_registrations.active.includes(:registrant)
      @allocated_by_registration = allocated_cents_by_registration(@event_registrations)
    end

    def assign_bulk_payment_card_data(submission)
      @submission = submission.reload.decorate
      @event_registrations = @event.event_registrations.active.includes(:registrant)
      @allocated_by_registration = allocated_cents_by_registration(@event_registrations)
    end

    def allocated_cents_by_registration(registrations)
      Allocation
        .where(allocatable_type: "EventRegistration", allocatable_id: registrations.ids)
        .group(:allocatable_id)
        .sum(:amount)
    end
  end
end
