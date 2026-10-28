class Membership::EnsureInvoice
  def self.call(membership:, covering: Date.current, cost_cents: nil)
    new(membership:, covering:, cost_cents:).call
  end

  def initialize(membership:, covering: Date.current, cost_cents: nil)
    @membership = membership
    @covering = covering.to_date
    @cost_cents = cost_cents
  end

  def call
    @membership.with_lock do
      existing = @membership.membership_invoices.active_on(@covering).first
      next existing if existing.present?

      next if @membership.locked? || !@membership.renewal_on?

      invoice = @membership.membership_invoices.new(
        start_date: @covering,
        end_date: @covering + Membership::INVOICE_PERIOD - 1.day,
        cost_cents: @cost_cents || @membership.cost_cents || Membership.annual_cost_cents
      )
      next unless invoice.save

      if @membership.end_date.blank? || invoice.end_date > @membership.end_date
        @membership.update(end_date: invoice.end_date)
      end

      invoice
    end
  end
end
