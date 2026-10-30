class Membership::Reconcile::Action
  OPERATIONS = %w[
    reconcile_attempt check_checkout clear_checkout
    apply_payment use_intent record_charge fail_attempt clear_missing_intent
  ].freeze

  Result = Data.define(:status, :message, :errors) do
    def success? = errors.blank?
  end

  def self.call(invoice:, params:)
    new(invoice:, params:).call
  end

  def initialize(invoice:, params:)
    @invoice = invoice
    @params = params
  end

  def call
    return failure("Choose a reconciliation action.") unless OPERATIONS.include?(operation)

    case operation
    when "reconcile_attempt"
      with_attempt { |attempt| Membership::Reconcile.call(attempt:) }
    when "check_checkout"
      Membership::Reconcile::Checkout.call(invoice: @invoice)
    when "clear_checkout"
      clear_checkout
    when "apply_payment"
      apply_payment
    when "use_intent"
      apply_intent
    when "record_charge"
      record_charge
    when "fail_attempt"
      with_attempt { |attempt| Membership::Reconcile::FailAttempt.call(attempt:) }
    when "clear_missing_intent"
      with_attempt { |attempt| Membership::Reconcile::ClearMissingIntent.call(attempt:) }
    end
  end

  private

  def operation = @params[:operation].to_s

  def clear_checkout
    return failure("This invoice has no checkout session to clear.") if @invoice.checkout_session_id.blank?

    @invoice.with_lock do
      @invoice.reload
      next failure("This checkout is still in progress.") if @invoice.payment_in_progress?

      @invoice.clear_payment_in_progress!
      Result.new(
        status: :cleared,
        message: "Cleared the stale checkout session. The invoice can be paid again.",
        errors: []
      )
    end
  end

  def with_attempt
    attempt = @invoice.charge_attempts.find_by(id: @params[:attempt_id])
    return failure("That payment attempt doesn't belong to this invoice.") if attempt.blank?

    yield attempt
  end

  def apply_payment
    with_payment do |payment|
      if @invoice.payment_in_progress?
        failure("A payment is already in progress for this invoice. Wait for it to finish or cancel it first.")
      else
        Membership::Reconcile::Payment.call(invoice: @invoice, payment:)
      end
    end
  end

  def with_payment
    payment = ExternalProcessorPayment.find_by(id: @params[:payment_id], person_id: @invoice.person.id)
    return failure("Payment not found for this member.") if payment.blank?

    yield payment
  end

  def apply_intent
    intent = retrieve_intent
    return failure(@intent_error) if intent.blank? && @intent_error.present?
    return failure("Choose a Stripe payment first.") if intent.blank?

    attempt = nil
    if @params[:attempt_id].present?
      attempt = @invoice.charge_attempts.find_by(id: @params[:attempt_id])
      return failure("That payment attempt doesn't belong to this invoice.") if attempt.blank?
    end

    if attempt
      Membership::Reconcile.call(attempt:, intent:)
    else
      Membership::Reconcile::Charge.call(invoice: @invoice, intent:)
    end
  end

  def record_charge
    intent = retrieve_intent
    return failure(@intent_error) if intent.blank? && @intent_error.present?
    return failure("Choose a Stripe payment first.") if intent.blank?

    attempt = nil
    if @params[:attempt_id].present?
      attempt = @invoice.charge_attempts.find_by(id: @params[:attempt_id])
      return failure("That payment attempt doesn't belong to this invoice.") if attempt.blank?
    end

    Membership::Reconcile::RecordCharge.call(invoice: @invoice, intent:, attempt:)
  end

  def retrieve_intent
    return if @params[:payment_intent_id].blank?

    customer = @invoice.person.stripe_customer
    Stripe::PaymentIntent.retrieve(
      { id: @params[:payment_intent_id], expand: [ "latest_charge" ] },
      { stripe_account: customer&.stripe_account }.compact
    )
  rescue Stripe::StripeError => e
    @intent_error = "Could not retrieve that Stripe payment: #{e.message}"
    nil
  end

  def failure(message)
    Result.new(status: :error, message:, errors: [ message ])
  end
end
