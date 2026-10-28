class Membership::Autopay::Charge
  Result = Struct.new(:attempt, :errors, keyword_init: true) do
    def success? = errors.blank?
  end

  def self.call(invoice:, actor: nil)
    new(invoice:, actor:).call
  end

  def initialize(invoice:, actor: nil)
    @invoice = invoice
    @actor = actor
  end

  def call
    return failure("This invoice is not due yet.") if @invoice.start_date > Date.current
    return failure("This invoice has no balance to pay.") unless @invoice.remaining_cost.positive?
    return failure("A payment is already in progress for this invoice.") if @invoice.payment_in_progress?
    if @invoice.latest_attempt&.succeeded? && @invoice.remaining_cost.positive?
      return failure("The last charge succeeded but has not been applied yet.")
    end

    processor = @invoice.person.payment_processor
    card = processor&.payment_methods&.order(default: :desc, id: :desc)&.first
    return failure("No card is on file for this member.") if processor.blank? || card.blank?

    attempt = create_attempt
    return attempt if attempt.is_a?(Result)
    return failure("Could not start a charge attempt.") if attempt.blank?

    charge(attempt, processor, card)
  rescue ActiveRecord::RecordNotUnique
    failure("A charge is already in progress for this invoice.")
  end

  def failure(message)
    Result.new(attempt: nil, errors: Array(message))
  end

  private

  def create_attempt
    @invoice.with_lock do
      @invoice.reload
      return failure("This invoice has no balance to pay.") unless @invoice.remaining_cost.positive?

      return failure("A charge is already in progress for this invoice.") if @invoice.charge_attempts.pending.exists?

      unresolved = @invoice.charge_attempts
        .where(status: %w[unknown needs_action])
        .where("attempted_at > ?", 24.hours.ago).exists?
      return failure("The last charge still needs attention.") if unresolved

      number = (@invoice.charge_attempts.maximum(:attempt_number) || 0) + 1
      @invoice.charge_attempts.create!(
        attempt_number: number,
        status: "pending",
        amount_cents: @invoice.remaining_cost,
        attempted_at: Time.current
      )
    end
  end

  def charge(attempt, processor, card)
    intent = Stripe::PaymentIntent.create(
      {
        amount: attempt.amount_cents,
        currency: Membership::CURRENCY,
        customer: processor.processor_id,
        payment_method: card.processor_id,
        confirm: true,
        off_session: true,
        description: "AWBW annual membership",
        metadata: {
          membership_id: @invoice.membership_id,
          membership_invoice_id: @invoice.id
        }
      },
      {
        idempotency_key: "membership-invoice-#{@invoice.id}-attempt-#{attempt.attempt_number}",
        stripe_account: processor.stripe_account
      }.compact
    )

    attempt.update_column(:payment_intent_id, intent.id)

    case intent.status
    when "succeeded"
      begin
        pay_charge = Pay::Stripe::Charge.sync(intent.latest_charge) if intent.latest_charge.present?
        attempt.update!(status: "succeeded", pay_charge: pay_charge)
        Result.new(attempt:, errors: [])
      rescue StandardError => e
        Rails.error.report(e, handled: true, source: "membership.autopay.sync")
        attempt.update!(status: "unknown", error_code: "sync_failed", error_message: e.message)
        failure_with(attempt, "The charge succeeded but could not be recorded yet.")
      end
    when "requires_action", "requires_confirmation"
      attempt.update!(
        status: "needs_action",
        payment_intent_id: intent.id,
        error_code: "authentication_required",
        error_message: "The card needs the member to complete the payment."
      )
      failure_with(attempt, "The card needs the member to finish the payment.")
    when "requires_payment_method", "canceled"
      error = intent.last_payment_error
      attempt.update!(
        status: "failed",
        payment_intent_id: intent.id,
        error_code: error&.code || intent.status,
        error_message: error&.message || "The card was declined.",
        next_attempt_on: Date.current + 1.day
      )
      failure_with(attempt, error&.message || "The card was declined.")
    else
      attempt.update!(
        status: "unknown",
        payment_intent_id: intent.id,
        error_code: intent.status,
        error_message: "The charge is still processing."
      )
      failure_with(attempt, "The charge is still processing.")
    end
  rescue Stripe::StripeError, Pay::Error => e
    attempt.update!(
      status: "failed",
      error_code: e.respond_to?(:code) ? e.code : "stripe_error",
      error_message: e.message,
      next_attempt_on: Date.current + 1.day
    )
    failure_with(attempt, e.message)
  end

  def failure_with(attempt, message)
    Result.new(attempt:, errors: Array(message))
  end
end
