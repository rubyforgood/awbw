class Membership::RemoveNextYear
  Result = Struct.new(:removed, :errors, keyword_init: true) do
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
      invoice = @membership.next_invoice

      if invoice.present?
        return failure("A payment is in progress for next year.") if invoice.payment_in_progress?
        return failure("Next year has an unresolved payment attempt.") if invoice.unresolved_attempt?
        return failure("Next year already has payments applied. Refund it instead.") unless invoice.allocations.sum(:amount).zero?
        return failure("Next year is the membership's only invoice.") unless invoice.other_invoices?

        invoice.destroy!
      end

      @membership.update!(renewal_off_at: Time.current)
      Result.new(removed: invoice.present?, errors: [])
    end
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotDestroyed => e
    failure(e.record&.errors&.full_messages || [ e.message ])
  end

  private

  def failure(message)
    Result.new(removed: false, errors: Array(message))
  end
end
