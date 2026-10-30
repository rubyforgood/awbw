class Membership::Reconcile::RecordCharge
  Result = Data.define(:status, :payment, :message, :errors) do
    def success? = errors.blank?
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
    return failure("Stripe does not show this payment as succeeded.") unless @intent.status == "succeeded"
    return failure("This Stripe payment doesn't belong to this member.") unless related_to_member?

    charge = retrieve_charge
    return failure("Stripe reports success without a charge to record.") if charge.blank?

    PaymentServices::RecordStripeCharge.call(
      charge:,
      person: @invoice.person,
      pay_charge: sync_pay_charge,
      external_origin: false,
      metadata: (@intent.metadata || {}).to_h.merge(stripe_charge: charge.to_hash)
    )

    if @attempt
      Membership::Reconcile.call(attempt: @attempt, intent: @intent)
    else
      Membership::Reconcile::Charge.call(invoice: @invoice, intent: @intent)
    end
  rescue ActiveRecord::RecordInvalid => e
    failure(e.record.errors.full_messages.to_sentence)
  rescue Stripe::StripeError, Pay::Error => e
    failure("Could not record this charge: #{e.message}")
  end

  private

  def stripe_account = @invoice.person.stripe_customer&.stripe_account

  def stripe_options = { stripe_account: }.compact

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

  def retrieve_charge
    charge = @intent.latest_charge
    return charge unless charge.is_a?(String)
    return if charge.blank?

    Stripe::Charge.retrieve({ id: charge, expand: Pay::Stripe::Charge::EXPAND }, stripe_options)
  end

  def sync_pay_charge
    Pay::Stripe::Charge.sync_payment_intent(@intent.id, stripe_account:)
  rescue Stripe::StripeError, Pay::Error
    nil
  end

  def failure(message)
    Result.new(status: :error, payment: nil, message:, errors: [ message ])
  end
end
