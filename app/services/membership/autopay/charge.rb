class Membership::Autopay::Charge
  Result = Struct.new(:attempt, :errors, keyword_init: true) do
    def success? = errors.blank?
  end

  def self.call(invoice:)
    new(invoice:).call
  end

  # Re-read an unresolved attempt's PaymentIntent through Pay and run it through
  # the same state machine as a live charge. Backs the reconcile page/job.
  def self.reconcile(attempt)
    new(invoice: attempt.membership_invoice).reconcile(attempt)
  end

  def initialize(invoice:)
    @invoice = invoice
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

  def reconcile(attempt)
    return failure("This attempt has no PaymentIntent to reconcile.", attempt:) if attempt.payment_intent_id.blank?

    processor = @invoice.person.payment_processor
    return failure("No payment processor on file for this member.", attempt:) if processor.blank?

    payment = Pay::Payment.from_id(attempt.payment_intent_id, stripe_account: processor.stripe_account)
    apply_intent(attempt, payment.intent, processor)
  rescue Stripe::StripeError, Pay::Error => e
    failure(e.message, attempt:)
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
    # The Pay customer owns the Stripe account, customer id, and latest_charge
    # expansion. Price/description/metadata are ours.
    intent = processor.create_payment_intent(
      attempt.amount_cents,
      currency: Membership::CURRENCY,
      payment_method: card.processor_id,
      confirm: true,
      off_session: true,
      description: Membership::InvoiceCheckout::DESCRIPTION,
      metadata: {
        membership_id: @invoice.membership_id,
        membership_invoice_id: @invoice.id,
        attempt_number: attempt.attempt_number
      }
    )

    attempt.update_column(:payment_intent_id, intent.id)
    apply_intent(attempt, intent, processor)
  rescue Stripe::StripeError, Pay::Error => e
    attempt.update!(
      status: "failed",
      error_code: e.respond_to?(:code) ? e.code : "stripe_error",
      error_message: e.message,
      next_attempt_on: Date.current + 1.day
    )
    failure(e.message, attempt:)
  end

  # One state machine for both a live charge and a later reconciliation.
  def apply_intent(attempt, intent, processor)
    Pay::Payment.new(intent).validate

    case intent.status
    when "succeeded"
      record_success(attempt, intent, processor)
    when "requires_confirmation"
      record_needs_action(attempt, intent)
    when "canceled"
      record_failure(attempt, intent, message: "The payment was canceled.")
    else
      record_unknown(attempt, intent)
    end
  rescue Pay::ActionRequired => e
    record_needs_action(attempt, e.payment.intent)
  rescue Pay::InvalidPaymentMethod => e
    record_failure(attempt, e.payment.intent)
  end

  def record_success(attempt, intent, processor)
    charge = intent.latest_charge
    if charge.blank?
      return record_unknown(attempt, intent,
        error_code: "missing_charge",
        error_message: "Stripe reported success without a charge to record.")
    end

    begin
      # Pay expands latest_charge when it creates the intent; a reconciled intent
      # carries only the id, so fetch that one on the customer's account.
      if charge.is_a?(String)
        charge = Stripe::Charge.retrieve(
          { id: charge, expand: Pay::Stripe::Charge::EXPAND },
          { stripe_account: processor.stripe_account }.compact
        )
      end

      pay_charge = Pay::Stripe::Charge.sync(
        charge.id,
        object: charge,
        stripe_account: processor.stripe_account
      )
    rescue StandardError => e
      Rails.error.report(
        e,
        handled: true,
        source: "membership.autopay.sync",
        context: { membership_invoice_id: @invoice.id, payment_intent_id: intent.id }
      )
      return record_unknown(attempt, intent,
        error_code: "sync_failed",
        error_message: "The charge succeeded but could not be recorded yet.")
    end

    if pay_charge.blank?
      return record_unknown(attempt, intent,
        error_code: "sync_missing",
        error_message: "The charge could not be linked to a Pay customer.")
    end

    unless payment_applied?(pay_charge)
      return record_unknown(attempt, intent,
        error_code: "allocation_failed",
        error_message: "The charge succeeded but was not applied to this invoice. Check Stripe before retrying.")
    end

    attempt.update!(status: "succeeded", payment_intent_id: intent.id, pay_charge: pay_charge)
    Result.new(attempt:, errors: [])
  end

  # A succeeded charge is only a succeeded attempt if the invoice actually
  # received it. Pay's after_save_commit creates the payment and allocation
  # before sync returns, so this is a cheap verification, not a repair.
  def payment_applied?(pay_charge)
    return true if @invoice.reload.paid_in_full?

    payment = ExternalProcessorPayment.find_by(stripe_charge_id: pay_charge.processor_id)
    payment.present? && payment.allocations.exists?(allocatable: @invoice)
  end

  def record_needs_action(attempt, intent)
    attempt.update!(
      status: "needs_action",
      payment_intent_id: intent.id,
      error_code: "authentication_required",
      error_message: "The card needs the member to complete the payment."
    )
    failure("The card needs the member to finish the payment.", attempt:)
  end

  def record_failure(attempt, intent, message: nil)
    error = intent.last_payment_error
    message ||= error&.message || "The card was declined."

    attempt.update!(
      status: "failed",
      payment_intent_id: intent.id,
      error_code: error&.code || intent.status,
      error_message: message,
      next_attempt_on: Date.current + 1.day
    )
    failure(message, attempt:)
  end

  def record_unknown(attempt, intent, error_code: nil, error_message: nil)
    error_message ||= "The charge is still processing."

    attempt.update!(
      status: "unknown",
      payment_intent_id: intent.id,
      error_code: error_code || intent.status,
      error_message: error_message
    )
    failure(error_message, attempt:)
  end

  def failure(message, attempt: nil)
    Result.new(attempt:, errors: Array(message))
  end
end
