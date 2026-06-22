module Events
  # Admin-side invoice for an event. Renders a blank template prefilled with the
  # event's content (line item + cost); when a `submission_id` is supplied it
  # autofills the bill-to/attention from that bulk-payment submission.
  class InvoicesController < ApplicationController
    # Bulk-payment payers have no account; authorization (below) gates access.
    skip_before_action :authenticate_user!, only: [ :show ]
    before_action :set_event

    def show
      if params[:submission_id].present?
        # A bulk-payment submission's invoice is reachable by the payer (who has
        # no account), matching the public bulk-payment show page they're sent.
        @submission = FormSubmission.find(params[:submission_id])
        authorize! @submission, to: :show_invoice?
        @invoice = EventInvoice.from_bulk_payment(@submission)
      else
        # The blank template is an admin tool.
        authorize! @event, to: :invoice?
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
