module Events
  # Admin-side invoice for an event. Renders a blank template prefilled with the
  # event's content (line item + cost); when a `submission_id` is supplied it
  # autofills the bill-to/attention from that bulk-payment submission.
  class InvoicesController < ApplicationController
    include AhoyTracking

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

    # Records that an admin filled in and generated the blank template, keeping a
    # usage breadcrumb (who, which event, the entered details) in Ahoy without a
    # dedicated invoice model. Re-renders the filled-in form so it can be printed.
    def create
      authorize! @event, to: :invoice?
      @invoice = EventInvoice.from_event(@event)
      @entered = entered_invoice_fields

      # String keys so Ahoy's resource-dimension extraction (props["resource_type"])
      # ties the event to the record; `entered` is already string-keyed.
      track_event("generate.invoice", {
        "resource_type" => "Event",
        "resource_id" => @event.id,
        "resource_title" => @event.title
      }.merge(@entered.to_h))

      @event = @event.decorate
      flash.now[:notice] = "Invoice recorded."
      render :show
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end

    def entered_invoice_fields
      return {} unless params[:invoice].respond_to?(:permit)

      params.require(:invoice).permit(
        :bill_to, :attention, :number, :date, :reference, :client_id, :names,
        line_item: [ :date, :description, :quantity, :unit_price ]
      )
    end
  end
end
