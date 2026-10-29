class Membership::UpdateTerm
  Result = Struct.new(:membership, :errors, keyword_init: true) do
    def success? = errors.blank?
  end

  def self.call(membership:, start_date:, end_date:, cost_cents:)
    new(membership:, start_date:, end_date:, cost_cents:).call
  end

  def initialize(membership:, start_date:, end_date:, cost_cents:)
    @membership = membership
    @start_date = start_date.to_date
    @end_date = end_date.to_date
    @cost_cents = cost_cents
  end

  def call
    @membership.with_lock do
      return failure("The end date must be after the start date.") if @end_date < @start_date

      shortening = @end_date < @membership.end_date
      future = @membership.next_invoice

      if shortening && future.present? && future.start_date > @end_date
        return failure("A payment is in progress for next year. Try again shortly.") if future.payment_in_progress?

        # An unpaid, unstarted year is dropped. A paid/partially paid one stays
        # as issued; the term simply ends before it.
        if future.allocations.sum(:amount).zero? && future.other_invoices?
          future.destroy!
        end
      end

      @membership.start_date = @start_date
      @membership.end_date = @end_date
      @membership.cost_cents = @cost_cents
      @membership.autorenewal_cancelled_at = Time.current if shortening
      @membership.save!

      Result.new(membership: @membership, errors: [])
    end
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotDestroyed => e
    failure(e.record&.errors&.full_messages || [ e.message ])
  end

  private

  def failure(message)
    Result.new(membership: @membership, errors: Array(message))
  end
end
