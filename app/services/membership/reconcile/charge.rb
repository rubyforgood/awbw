class Membership::Reconcile::Charge
  Result = Data.define(:status, :payment, :pay_charge, :allocation, :message, :errors) do
    def success? = errors.blank?
    def allocated? = %i[applied already_applied].include?(status)
  end

  def self.call(invoice:, intent:, attempt: nil)
    new(invoice:, intent:, attempt:).call
  end

  def initialize(invoice:, intent:, attempt: nil)
    @invoice = invoice
    @intent = intent
    @attempt = attempt
  end

  def call
    unless @intent.status == "succeeded"
      return failure("Stripe shows this payment as #{@intent.status.humanize.downcase}; there is nothing to apply.")
    end

    return failure("This Stripe payment doesn't belong to this member.") unless related_to_member?

    pay_charge = Pay::Stripe::Charge.sync_payment_intent(
      @intent.id,
      stripe_account: stripe_account
    )

    payment = pay_charge.present? ? ExternalProcessorPayment.find_by(stripe_charge_id: pay_charge.processor_id) : nil
    payment ||= ExternalProcessorPayment.find_by(stripe_charge_id: charge_id) if charge_id.present?
    if payment.blank?
      return failure("Stripe charged this payment, but no local payment could be recorded. Check the charge in Stripe.")
    end

    result = Membership::Reconcile::Payment.call(invoice: @invoice, payment:)
    mark_attempt_succeeded(pay_charge) if result.allocated?

    Result.new(status: result.status, payment: result.payment, pay_charge:,
               allocation: result.allocation, message: result.message, errors: result.errors)
  rescue Stripe::StripeError, Pay::Error => e
    failure("Could not sync this charge with Stripe: #{e.message}")
  end

  private

  def stripe_account = @invoice.person.stripe_customer&.stripe_account

  def related_to_member?
    metadata = (@intent.metadata || {}).to_h.stringify_keys
    return true if metadata["membership_invoice_id"].to_s == @invoice.id.to_s
    return true if @invoice.charge_attempts.exists?(payment_intent_id: @intent.id)

    customer_id = @invoice.person.stripe_customer&.processor_id
    customer_id.present? && intent_customer_id == customer_id
  end

  def intent_customer_id
    customer = @intent.customer
    customer.is_a?(String) ? customer : customer&.id
  end

  def charge_id
    charge = @intent.latest_charge
    charge.is_a?(String) ? charge : charge&.id
  end

  def mark_attempt_succeeded(pay_charge)
    return if @attempt.blank?

    @attempt.update!(
      status: "succeeded",
      payment_intent_id: @intent.id,
      pay_charge: pay_charge || @attempt.pay_charge,
      error_code: nil,
      error_message: nil,
      next_attempt_on: nil
    )
  end

  def failure(message)
    Result.new(status: :error, payment: nil, pay_charge: nil, allocation: nil,
               message:, errors: [ message ])
  end
end
