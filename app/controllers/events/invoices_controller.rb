module Events
  # Admin-only blank invoice template for an event, prefilled with the event's
  # content (line item + cost). A bulk-payment submission's invoice is served by
  # BulkPaymentFormSubmissionsController#invoice (slug-based, payer-facing).
  class InvoicesController < ApplicationController
    # Kept skipped so an unauthorized viewer is denied by the policy (redirect to
    # root) rather than bounced to a sign-in page.
    skip_before_action :authenticate_user!, only: [ :show ]
    before_action :set_event

    def show
      authorize! @event, to: :invoice?
      @invoice = EventInvoice.from_event(@event)
      @event = @event.decorate
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end
  end
end
