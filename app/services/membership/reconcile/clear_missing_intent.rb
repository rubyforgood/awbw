class Membership::Reconcile::ClearMissingIntent
  Result = Data.define(:status, :attempt, :message, :errors) do
    def success? = errors.blank?
  end

  def self.call(attempt:)
    new(attempt:).call
  end

  def initialize(attempt:)
    @attempt = attempt
  end

  def call
    return failure("This attempt is already resolved.") unless @attempt.unresolved?
    return failure("This attempt has no PaymentIntent to clear.") if @attempt.payment_intent_id.blank?

    payment = Pay::Payment.from_id(@attempt.payment_intent_id, stripe_account: stripe_account)
    return failure("Stripe still has this PaymentIntent. Reconcile or cancel it instead.") if payment.present?

    clear_attempt!
  rescue Stripe::InvalidRequestError
    clear_attempt!
  rescue Stripe::StripeError, Pay::Error => e
    failure("Could not verify this PaymentIntent with Stripe: #{e.message}")
  end

  private

  def stripe_account = @attempt.membership_invoice.person.stripe_customer&.stripe_account

  def clear_attempt!
    @attempt.with_lock do
      @attempt.reload
      unless @attempt.unresolved? && @attempt.payment_intent_id.present?
        next failure("This attempt is already resolved.")
      end

      @attempt.update!(
        status: "failed",
        payment_intent_id: nil,
        error_code: "intent_not_found",
        error_message: "PaymentIntent not found in Stripe.",
        next_attempt_on: Date.current + 1.day
      )

      Result.new(
        status: :cleared,
        attempt: @attempt,
        message: "Cleared the missing PaymentIntent and marked the attempt failed. The invoice can retry.",
        errors: []
      )
    end
  end

  def failure(message)
    Result.new(status: :error, attempt: @attempt, message:, errors: [ message ])
  end
end
