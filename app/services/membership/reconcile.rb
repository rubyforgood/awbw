class Membership::Reconcile
  RESOLVED_STATUSES = %w[succeeded failed needs_card].freeze

  Result = Data.define(:status, :attempt, :payment, :message, :errors) do
    def success? = errors.blank?
  end

  def self.call(attempt:, intent: nil)
    new(attempt:, intent:).call
  end

  def initialize(attempt:, intent: nil)
    @attempt = attempt
    @invoice = attempt.membership_invoice
    @intent = intent
  end

  def call
    return failure("This attempt is already resolved.") if resolved?

    intent = @intent || retrieve_intent
    if intent.blank?
      return failure("No PaymentIntent is stored for this attempt. Review the Stripe payments on this page, " \
                     "or mark it failed if Stripe shows no charge.")
    end

    @intent = intent
    @attempt.update_column(:payment_intent_id, intent.id) if @attempt.payment_intent_id.blank?

    if intent.status == "succeeded"
      reconcile_success
    else
      apply_other_status
    end
  rescue Stripe::StripeError, Pay::Error => e
    failure("Could not reach Stripe: #{e.message}")
  end

  private

  def resolved? = RESOLVED_STATUSES.include?(@attempt.status)

  def retrieve_intent
    return if @attempt.payment_intent_id.blank?

    Pay::Payment.from_id(@attempt.payment_intent_id, stripe_account: stripe_account).intent
  end

  def stripe_account = @invoice.person.stripe_customer&.stripe_account

  def reconcile_success
    result = Membership::Reconcile::Charge.call(invoice: @invoice, intent: @intent, attempt: @attempt)

    if result.allocated?
      Result.new(status: :succeeded, attempt: @attempt.reload, payment: result.payment,
                 message: result.message, errors: [])
    elsif result.success? && result.payment.present?
      mark_unallocated(result.payment, result.message)
      Result.new(status: :succeeded, attempt: @attempt.reload, payment: result.payment,
                 message: "#{result.message} The attempt is marked succeeded; the payment remains unallocated.",
                 errors: [])
    else
      mark_unresolved("allocation_failed", result.message)
      Result.new(status: result.status, attempt: @attempt.reload, payment: result.payment,
                 message: result.message, errors: result.errors.presence || [ result.message ])
    end
  end

  def apply_other_status
    before = [ @attempt.status, @attempt.updated_at ]
    result = Membership::Autopay::Charge.reconcile(@attempt, payment: Pay::Payment.new(@intent))
    @attempt.reload
    applied = @attempt.status != before[0] || @attempt.updated_at != before[1]

    if result.errors.any? && !applied && !%w[failed needs_action unknown].include?(@attempt.status)
      return failure(result.errors.to_sentence)
    end

    case @attempt.status
    when "failed"
      success(:failed, "Stripe shows this attempt failed. The next automatic charge can retry.")
    when "needs_action"
      success(:needs_action, "The card still needs the member to finish authentication. " \
                             "If they can't, cancel the payment attempt.")
    when "unknown"
      success(:unknown, "Stripe is still processing this payment. Check again later.")
    else
      failure(result.errors.to_sentence.presence || "Stripe did not resolve this attempt.")
    end
  end

  def mark_unallocated(payment, message)
    @attempt.update!(
      status: "succeeded",
      payment_intent_id: @attempt.payment_intent_id || @intent.id,
      pay_charge: payment.pay_charge || @attempt.pay_charge,
      error_code: "unallocated_payment",
      error_message: "Stripe reports this charge succeeded, but the payment could not be applied " \
                     "to this invoice. #{message}",
      next_attempt_on: nil
    )
  end

  def mark_unresolved(code, message)
    return unless @attempt.unresolved?

    @attempt.update!(
      status: "unknown",
      payment_intent_id: @attempt.payment_intent_id || @intent.id,
      error_code: code,
      error_message: message
    )
  end

  def success(status, message)
    Result.new(status:, attempt: @attempt, payment: nil, message:, errors: [])
  end

  def failure(message)
    Result.new(status: :error, attempt: @attempt, payment: nil, message:, errors: [ message ])
  end
end
