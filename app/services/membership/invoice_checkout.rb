class Membership::InvoiceCheckout
  DESCRIPTION = "AWBW annual membership".freeze

  def self.call(invoice:, success_url:, cancel_url:, autopay: false, save_card: true)
    new(invoice:, success_url:, cancel_url:, autopay:, save_card:).call
  end

  def initialize(invoice:, success_url:, cancel_url:, autopay: false, save_card: true)
    @invoice = invoice
    @success_url = success_url
    @cancel_url = cancel_url
    @autopay = autopay
    @save_card = save_card
  end

  def call
    @invoice.mark_payment_in_progress!
    person = @invoice.person
    person.set_payment_processor :stripe

    metadata = { membership_id: @invoice.membership_id, membership_invoice_id: @invoice.id }
    metadata[:autopay] = "true" if @autopay

    person.payment_processor.checkout(
      mode: "payment",
      metadata: metadata,
      payment_intent_data: {
        metadata: metadata,
        setup_future_usage: ("off_session" if @save_card)
      }.compact,
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
    @invoice.clear_payment_in_progress!
    raise
  end
end
