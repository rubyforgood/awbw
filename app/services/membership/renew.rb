class Membership::Renew
  Result = Struct.new(:membership, :invoice, :errors, keyword_init: true) do
    def success? = errors.blank?
  end

  def self.call(membership:, force: false)
    new(membership:, force:).call
  end

  def initialize(membership:, force: false)
    @membership = membership
    @force = force
  end

  def call
    @membership.with_lock do
      return failure("This membership is locked.") if @membership.locked?
      return failure("Renewal is turned off.") unless @membership.renewal_on?
      return failure("The next year has already been issued.") if @membership.next_invoice.present?
      return failure("The membership term has already ended.") if @membership.end_date.blank? || @membership.end_date < Date.current - 1.day
      unless @force || @membership.end_date <= Date.current + Membership.renewal_window_days
        return failure("This membership is not in its renewal window yet.")
      end

      ending_invoice = @membership.membership_invoices.order(:end_date).last
      return failure("There is no invoice to settle.") if ending_invoice.blank?

      if ending_invoice.end_date > @membership.end_date
        return failure("The membership term ends before its invoice coverage. Extend the term first.")
      end

      return failure("The ending period is not settled.") unless ending_invoice.paid_in_full?

      new_start = ending_invoice.end_date + 1.day
      new_end = new_start + Membership::INVOICE_PERIOD - 1.day

      invoice = @membership.membership_invoices.create!(
        start_date: new_start,
        end_date: new_end,
        cost_cents: @membership.cost_cents || Membership.annual_cost_cents
      )
      @membership.update!(end_date: new_end)

      Result.new(membership: @membership, invoice:, errors: [])
    end
  rescue ActiveRecord::RecordInvalid => e
    failure(e.record.errors.full_messages)
  end

  private

  def failure(message)
    Result.new(membership: @membership, invoice: nil, errors: Array(message))
  end
end
