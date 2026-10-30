class Membership::Reconcile::FailAttempt
  Result = Data.define(:status, :attempt, :message, :errors) do
    def success? = errors.blank?
  end

  def self.call(attempt:, message: "No charge found in Stripe.")
    new(attempt:, message:).call
  end

  def initialize(attempt:, message:)
    @attempt = attempt
    @message = message
  end

  def call
    return failure("This attempt still needs the member to finish authentication.") if @attempt.needs_action?
    unless @attempt.manual_failure_allowed?
      return failure("Only an unresolved attempt with no PaymentIntent can be marked failed manually.")
    end

    @attempt.with_lock do
      @attempt.reload
      unless @attempt.manual_failure_allowed?
        next failure("This attempt is already resolved.")
      end

      @attempt.update!(
        status: "failed",
        error_code: "manually_resolved",
        error_message: @message,
        next_attempt_on: Date.current + 1.day
      )

      Result.new(
        status: :failed,
        attempt: @attempt,
        message: "Marked attempt ##{@attempt.attempt_number} failed. The next automatic charge can retry.",
        errors: []
      )
    end
  end

  private

  def failure(message)
    Result.new(status: :error, attempt: @attempt, message:, errors: [ message ])
  end
end
