class Membership::InvoiceCheckout
  DESCRIPTION = "AWBW annual membership".freeze

  def self.call(invoice:, success_url:, cancel_url:)
    new(invoice:, success_url:, cancel_url:).call
  end

  def initialize(invoice:, success_url:, cancel_url:)
    @invoice = invoice
    @success_url = success_url
    @cancel_url = cancel_url
  end

  def call
    claimed = claim_invoice
    return unless claimed

    person = @invoice.person
    person.set_payment_processor :stripe

    metadata = { membership_id: @invoice.membership_id, membership_invoice_id: @invoice.id }

    person.payment_processor.checkout(
      mode: "payment",
      metadata: metadata,
      payment_intent_data: { metadata: metadata },
      line_items: [ {
        price_data: {
          currency: Membership::CURRENCY,
          product_data: { name: DESCRIPTION },
          unit_amount: @invoice.remaining_cost
        },
        quantity: 1
      } ],
      expires_at: 1.hour.from_now.to_i,
      success_url: @success_url,
      cancel_url: @cancel_url
    )
  rescue StandardError
    @invoice.clear_payment_in_progress! if claimed
    raise
  end

  private

  # A short row lock makes the check-and-mark atomic. The timestamp is the
  # durable reservation: once this transaction commits, later requests see it.
  # Do not hold the lock while talking to Stripe.
  def claim_invoice
    @invoice.with_lock do
      @invoice.reload
      next false if @invoice.payment_in_progress?

      @invoice.mark_payment_in_progress!
      true
    end
  end
end
