class Membership::Reconcile::Lookup
  Result = Data.define(:candidates, :local_payments, :message, :errors) do
    def success? = errors.blank?
  end

  Candidate = Data.define(
    :payment_intent_id, :status, :amount_cents, :currency, :created_at,
    :attempt_number, :charge_id, :attempt, :payment, :allocated
  ) do
    def succeeded? = status == "succeeded"
    def payment_remaining_cents = payment&.amount_cents_remaining.to_i

    def can_link_attempt?
      attempt.present? && attempt.unresolved? && attempt.payment_intent_id.blank?
    end

    def can_apply? = payment.present? && payment_remaining_cents.positive? && !allocated
  end

  LIMIT = 100

  def self.call(invoice:)
    new(invoice:).call
  end

  def initialize(invoice:)
    @invoice = invoice
  end

  def call
    local_payments = local_payments_for_invoice

    customer = @invoice.person.stripe_customer
    return failure("This member has no Stripe customer.", local_payments:) if customer.blank?
    return failure("This member's Stripe customer has no processor id.", local_payments:) if customer.processor_id.blank?

    intents = Stripe::PaymentIntent.list(
      { customer: customer.processor_id, limit: LIMIT },
      stripe_options(customer)
    ).data

    matching = intents.select do |intent|
      metadata_for(intent)["membership_invoice_id"].to_s == @invoice.id.to_s
    end

    charge_ids = matching.filter_map { |intent| charge_id(intent) }
    payments = ExternalProcessorPayment
      .where(stripe_charge_id: charge_ids)
      .includes(:allocations)
      .index_by(&:stripe_charge_id)

    candidates = matching.map { |intent| candidate_for(intent, payments[charge_id(intent)]) }
      .sort_by(&:created_at)
      .reverse

    candidate_payment_ids = candidates.filter_map { |candidate| candidate.payment&.id }
    local_payments = local_payments.reject { |payment| candidate_payment_ids.include?(payment.id) }

    Result.new(
      candidates:,
      local_payments:,
      message: candidates.any? ? nil : "No Stripe payments found for this invoice.",
      errors: []
    )
  rescue Stripe::StripeError, Pay::Error => e
    failure("Could not search Stripe: #{e.message}", local_payments:)
  end

  private

  def local_payments_for_invoice
    attempt_linked = @invoice.stripe_payments_with_remaining.includes(:allocations).to_a
    metadata_linked = ExternalProcessorPayment.membership_originated
      .where(amount_cents_remaining: 1..)
      .select { |payment| MembershipPaymentLink.new(payment).invoice == @invoice }

    (attempt_linked + metadata_linked).uniq(&:id)
  end

  def candidate_for(intent, payment)
    cid = charge_id(intent)
    attempt = find_attempt(intent)
    allocated = payment.present? && payment.allocations.any? { |allocation|
      allocation.allocatable_type == @invoice.class.polymorphic_name &&
        allocation.allocatable_id == @invoice.id
    }

    Candidate.new(
      payment_intent_id: intent.id,
      status: intent.status,
      amount_cents: intent.amount,
      currency: intent.currency,
      created_at: Time.zone.at(intent.created),
      attempt_number: metadata_for(intent)["attempt_number"].presence,
      charge_id: cid,
      attempt:,
      payment:,
      allocated:
    )
  end

  def find_attempt(intent)
    number = metadata_for(intent)["attempt_number"].presence
    @invoice.charge_attempts.find_by(payment_intent_id: intent.id) ||
      (number && @invoice.charge_attempts.find_by(attempt_number: number))
  end

  def metadata_for(intent)
    (intent.metadata || {}).to_h.stringify_keys
  end

  def charge_id(intent)
    charge = intent.latest_charge
    charge.is_a?(String) ? charge : charge&.id
  end

  def stripe_options(customer)
    { stripe_account: customer.stripe_account }.compact
  end

  def failure(message, local_payments: [])
    Result.new(candidates: [], local_payments:, message:, errors: [ message ])
  end
end
