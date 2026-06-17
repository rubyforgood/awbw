module Events
  # Admin-side invoice for an event. Renders a blank template prefilled with the
  # event's content (line item + cost); when a `submission_id` is supplied it
  # autofills the bill-to/attention from that bulk-payment submission.
  class InvoicesController < ApplicationController
    before_action :set_event

    def show
      authorize! @event, to: :invoice?

      if params[:submission_id].present?
        @submission = FormSubmission.find(params[:submission_id])
        @invoice = EventInvoice.from_bulk_payment(@submission)
      else
        @invoice = EventInvoice.from_event(@event)
      end

      @event = @event.decorate
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end
  end
end
