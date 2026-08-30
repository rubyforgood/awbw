module BulkPaymentsHelper
  # Link from the global bulk payments index to a submission's row on its event's
  # bulk payments page: scrolls to the card (`#payment-card-<id>`), expands it, and
  # paints the yellow highlight ring — the same anchor+highlight round trip the
  # registrants roster uses. `return_to` lets that page's eyebrow come back here.
  def event_bulk_payment_row_path(event, submission)
    bulk_payments_event_path(
      event,
      expand: submission.id,
      highlight: submission.id,
      anchor: "payment-card-#{submission.id}",
      return_to: "bulk_payments_index"
    )
  end
end
