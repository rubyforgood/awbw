class Membership::Reconcile::Checkout
  Result = Data.define(:status, :session, :payment, :message, :errors) do
    def success? = errors.blank?
  end

  def self.call(invoice:)
    new(invoice:).call
  end

  def initialize(invoice:)
    @invoice = invoice
  end

  def call
    return failure("This invoice has no checkout session to check.") if @invoice.checkout_session_id.blank?

    session = Stripe::Checkout::Session.retrieve(
      { id: @invoice.checkout_session_id, expand: [ "payment_intent" ] },
      stripe_options
    )

    case session.status
    when "complete"
      check_complete(session)
    when "expired"
      clear_checkout_state
      Result.new(status: :expired, session:, payment: nil,
                 message: "This checkout session expired. The invoice can be paid again.", errors: [])
    when "open"
      failure("This checkout session is still open. Cancel it or wait for it to expire.")
    else
      failure("Stripe reports this checkout session as #{session.status}.")
    end
  rescue Stripe::StripeError, Pay::Error => e
    failure("Could not check the checkout session with Stripe: #{e.message}")
  end

  private

  def check_complete(session)
    unless session.payment_status == "paid"
      return failure("Stripe completed this checkout but the payment is not paid.")
    end

    intent = session.payment_intent
    return failure("Stripe completed this checkout without a PaymentIntent.") if intent.blank?

    intent = retrieve_intent(intent) if intent.is_a?(String)
    result = Membership::Reconcile::Charge.call(invoice: @invoice, intent:)

    clear_checkout_state if result.success?
    Result.new(status: :complete, session:, payment: result.payment,
               message: result.message, errors: result.errors)
  end

  def retrieve_intent(id)
    Stripe::PaymentIntent.retrieve({ id: }, stripe_options)
  end

  def clear_checkout_state
    @invoice.with_lock do
      @invoice.reload
      @invoice.clear_payment_in_progress!
    end
  end

  def stripe_options = { stripe_account: @invoice.person.stripe_customer&.stripe_account }.compact

  def failure(message)
    Result.new(status: :error, session: nil, payment: nil, message:, errors: [ message ])
  end
end
