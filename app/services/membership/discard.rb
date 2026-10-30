class Membership::Discard
  Result = Data.define(:membership, :errors) do
    def success? = errors.blank?
  end

  def self.call(membership:)
    new(membership:).call
  end

  def initialize(membership:)
    @membership = membership
  end

  def call
    @membership.with_lock do
      return failure("This membership is locked.") if @membership.locked?

      unless @membership.deletable? || @membership.discardable?
        return failure("Cannot delete this membership because #{@membership.discard_blocked_reason}.")
      end

      @membership.membership_invoices.each { |invoice| invoice.skip_deletion_guard = true }
      @membership.skip_deletion_guard = true
      @membership.destroy!
    end

    Result.new(membership: @membership, errors: [])
  rescue ActiveRecord::RecordNotDestroyed => e
    failure(e.record&.errors&.full_messages || [ e.message ])
  end

  private

  def failure(message)
    Result.new(membership: @membership, errors: Array(message))
  end
end
