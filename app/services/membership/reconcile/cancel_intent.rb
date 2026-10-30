# Cancels an abandoned card-authentication PaymentIntent in Stripe, then runs the
# normal reconcile state machine so the attempt is marked failed and the invoice
# is released. This is a deliberate business action, not reconciliation rewriting
# Stripe data: no money has moved, and the PaymentIntent is stopped.
class Membership::Reconcile::CancelIntent
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
    unless @attempt.needs_action?
      return failure("Only a card-authentication attempt can be canceled.")
    end
    return failure("This attempt has no PaymentIntent to cancel.") if @attempt.payment_intent_id.blank?

    customer = @attempt.membership_invoice.person.stripe_customer
    options = { stripe_account: customer&.stripe_account }.compact
    intent = Pay::Payment.from_id(@attempt.payment_intent_id, stripe_account: options[:stripe_account]).intent

    return complete_elsewhere if intent.status == "succeeded"

    canceled_intent =
      if intent.status == "canceled"
        intent
      else
        Stripe::PaymentIntent.cancel({ id: intent.id }, options)
      end

    Membership::Autopay::Charge.reconcile(@attempt, payment: Pay::Payment.new(canceled_intent))
    @attempt.reload

    unless @attempt.failed?
      return failure("Stripe canceled the payment, but the attempt could not be marked failed. Try reconciling it.")
    end

    @attempt.update!(error_code: "canceled_by_admin", error_message: "Canceled by an admin.")
    Result.new(status: :canceled, attempt: @attempt,
               message: "Canceled the payment attempt. The invoice can be retried.", errors: [])
  rescue Stripe::InvalidRequestError
    complete_elsewhere
  rescue Stripe::StripeError, Pay::Error => e
    failure("Could not cancel this payment with Stripe: #{e.message}")
  end

  private

  # The member may finish authentication between our read and the cancel. If so,
  # the charge succeeded and the normal reconcile applies it instead.
  def complete_elsewhere
    result = Membership::Reconcile.call(attempt: @attempt)
    if result.success? && @attempt.reload.succeeded?
      Result.new(status: :succeeded, attempt: @attempt,
                 message: "The member completed authentication first; the payment was applied.", errors: [])
    else
      failure("Stripe could not cancel this payment. Reconcile the attempt to see its current status.")
    end
  end

  def failure(message)
    Result.new(status: :error, attempt: @attempt, message:, errors: [ message ])
  end
end
