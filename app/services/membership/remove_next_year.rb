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
        return failure("Next year already has payments applied. Refund it instead.") unless invoice.allocations.sum(:amount).zero?
        return failure("Next year is the membership's only invoice.") unless invoice.other_invoices?

        removed_end = invoice.end_date
        invoice.destroy!

        if @membership.end_date == removed_end
          previous_end = @membership.membership_invoices.reload.maximum(:end_date)
          @membership.update!(end_date: previous_end) if previous_end
        end
      end

      @membership.update!(autorenewal_cancelled_at: Time.current)
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
