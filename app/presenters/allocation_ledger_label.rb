# Shared labelling for an allocation shown in a money-document ledger — the
# invoice's applied-payments list and the receipt's payment ledger — so the two
# can't drift. Payment is an STI base whose polymorphic source_type is always
# "Payment"; the concrete subclass tells us how it was paid, so payments are named
# by method (Cash/Check/Credit card), with the check number as a reference.
# Non-payment allocations (scholarships, discounts) fall back to their humanized
# type.
module AllocationLedgerLabel
  PAYMENT_METHOD_LABELS = {
    "CashPayment" => "Cash",
    "CheckPayment" => "Check",
    "ExternalProcessorPayment" => "Credit card",
    "FilemakerPayment" => "Payment"
  }.freeze

  module_function

  def method_label(allocation)
    if allocation.source_type == Payment.polymorphic_name
      PAYMENT_METHOD_LABELS[allocation.source&.class&.name] || "Payment"
    else
      allocation.source_type.underscore.humanize
    end
  end

  # Check number, when the payment was a check — so the payer can reconcile it
  # against their own records.
  def reference_for(allocation)
    source = allocation.source
    return unless source.is_a?(CheckPayment) && source.check_number.present?
    "Check ##{source.check_number}"
  end
end
