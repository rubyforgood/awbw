class Membership::InvoiceCheckout
  DESCRIPTION = "AWBW annual membership".freeze
  IN_PROGRESS_ERROR = "A payment is already in progress for this invoice.".freeze
  COMPLETED_ERROR = "This payment is already being processed by Stripe.".freeze

  Result = Struct.new(:session, :errors, keyword_init: true) do
    def success? = errors.blank?
  end

  CancelResult = Struct.new(:cancelled, :errors, keyword_init: true) do
    def success? = cancelled
  end

  def self.call(invoice:, success_url:, cancel_url:, save_card: false)
    new(invoice:, success_url:, cancel_url:, save_card:).call
  end

  def self.cancel(invoice:, session_id: nil)
    new(invoice:).cancel(session_id:)
  end

  def initialize(invoice:, success_url: nil, cancel_url: nil, save_card: false)
    @invoice = invoice
    @success_url = success_url
    @cancel_url = cancel_url
    @save_card = save_card
  end

  def call
    if @invoice.payment_in_progress? || @invoice.checkout_session_id.present?
      resume_or_create
    else
      claim_and_create
    end
  end

  def cancel(session_id: nil)
    session_id = session_id.presence || @invoice.checkout_session_id
    return cancel_failure("No checkout session to cancel.") if session_id.blank?

    session = retrieve_session(session_id)

    case session.status
    when "open"
      if expire_session(session_id)
        clear_cancelled_session(session_id)
      else
        cancel_failure("This payment can no longer be cancelled.")
      end
    when "expired"
      clear_cancelled_session(session_id)
    else
      cancel_failure("This payment can no longer be cancelled.")
    end
  rescue Stripe::StripeError => e
    Rails.error.report(
      e,
      handled: true,
      source: "membership.invoice_checkout.cancel",
      context: { membership_invoice_id: @invoice.id, checkout_session_id: session_id }
    )
    cancel_failure("Could not cancel the payment with Stripe. Please try again.")
  end

  private

  def resume_or_create
    session_id = @invoice.checkout_session_id
    return claim_and_create if session_id.blank?

    session = begin
      retrieve_session(session_id)
    rescue Stripe::InvalidRequestError
      return claim_and_create(replacing_session_id: session_id)
    end

    case session.status
    when "open"
      return Result.new(errors: [ IN_PROGRESS_ERROR ]) if @save_card

      Result.new(session:)
    when "expired"
      claim_and_create(replacing_session_id: session_id)
    when "complete"
      Result.new(errors: [ COMPLETED_ERROR ])
    else
      Result.new(errors: [ IN_PROGRESS_ERROR ])
    end
  end

  def claim_and_create(replacing_session_id: nil)
    claimed = claim_invoice(replacing_session_id:)
    return Result.new(errors: [ IN_PROGRESS_ERROR ]) unless claimed

    session = nil
    person = @invoice.person
    processor = person.stripe_payment_processor

    metadata = { membership_id: @invoice.membership_id, membership_invoice_id: @invoice.id }
    payment_intent_data = { metadata: metadata }
    payment_intent_data[:setup_future_usage] = "off_session" if @save_card

    session = processor.checkout(
      mode: "payment",
      metadata: metadata,
      payment_intent_data: payment_intent_data,
      line_items: [ {
        price_data: {
          currency: Membership::CURRENCY,
          product_data: { name: DESCRIPTION },
          unit_amount: @invoice.remaining_cost
        },
        quantity: 1
      } ],
      expires_at: MembershipInvoice::PAYMENT_WINDOW.from_now.to_i,
      success_url: @success_url,
      cancel_url: @cancel_url
    )
    store_session_id(session)
    Result.new(session:)
  rescue StandardError
    @invoice.clear_payment_in_progress! if claimed && session.nil?
    raise
  end

  # A short row lock makes the check-and-mark atomic. The timestamp is the
  # durable reservation: once this transaction commits, later requests see it.
  # Do not hold the lock while talking to Stripe.
  def claim_invoice(replacing_session_id: nil)
    @invoice.with_lock do
      @invoice.reload
      if replacing_session_id
        next false unless @invoice.checkout_session_id == replacing_session_id

        @invoice.clear_payment_in_progress!
      end
      next false if @invoice.payment_in_progress?
      next false if @invoice.charge_attempts
        .where(status: %w[pending unknown needs_action])
        .exists?

      @invoice.mark_payment_in_progress!
      true
    end
  end

  def clear_cancelled_session(session_id)
    cleared = @invoice.with_lock do
      @invoice.reload
      next false if @invoice.checkout_session_id.present? && @invoice.checkout_session_id != session_id

      @invoice.clear_payment_in_progress!
      true
    end

    return CancelResult.new(cancelled: true) if cleared

    cancel_failure("A newer payment is already in progress for this invoice.")
  end

  def retrieve_session(session_id)
    Stripe::Checkout::Session.retrieve(session_id)
  end

  def expire_session(session_id)
    Stripe::Checkout::Session.expire(session_id)
    true
  rescue Stripe::InvalidRequestError
    # It may have expired, or been paid, between our retrieve and expire calls.
    retrieve_session(session_id).status == "expired"
  end

  def store_session_id(session)
    MembershipInvoice.where(id: @invoice.id)
      .where.not(payment_in_progress_at: nil)
      .update_all(checkout_session_id: session.id)
    @invoice.reload
  end

  def cancel_failure(message)
    CancelResult.new(cancelled: false, errors: [ message ])
  end
end
