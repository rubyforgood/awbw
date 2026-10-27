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
    person = @invoice.person
    person.set_payment_processor :stripe

    metadata = { membership_id: @invoice.membership_id, membership_invoice_id: @invoice.id }

    person.payment_processor.checkout(
      mode: "payment",
      metadata: metadata,
      payment_intent_data: { metadata: metadata },
      line_items: [ {
        price_data: {
          currency: "usd",
          product_data: { name: DESCRIPTION },
          unit_amount: @invoice.remaining_cost
        },
        quantity: 1
      } ],
      success_url: @success_url,
      cancel_url: @cancel_url
    )
  end
end
