class Membership::UpdateTerm
  Result = Struct.new(:membership, :errors, keyword_init: true) do
    def success? = errors.blank?
  end

  def self.call(membership:, start_date:, end_date:, cost_cents:, renewal_on:)
    new(membership:, start_date:, end_date:, cost_cents:, renewal_on:).call
  end

  def initialize(membership:, start_date:, end_date:, cost_cents:, renewal_on:)
    @membership = membership
    @start_date = start_date.to_date
    @end_date = end_date.to_date
    @cost_cents = cost_cents
    @renewal_on = renewal_on
  end

  def call
    @membership.with_lock do
      return failure("The end date must be after the start date.") if @end_date < @start_date

      shortening = @end_date < @membership.end_date
      future = @membership.next_invoice

      if shortening && future.present?
        return failure("Next year already has payments applied. Refund it, or keep the term.") unless future.allocations.sum(:amount).zero?

        if future.start_date > Date.current && future.other_invoices?
          future.destroy!
        end
      end

      @membership.start_date = @start_date
      @membership.end_date = @end_date
      @membership.cost_cents = @cost_cents
      @membership.autorenewal_cancelled = !@renewal_on
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
