class Membership::EnsureInvoice
  def self.call(membership:, covering: Date.current, cost_cents: nil)
    new(membership:, covering:, cost_cents:).call
  end

  def initialize(membership:, covering: Date.current, cost_cents: nil)
    @membership = membership
    @covering = covering
    @cost_cents = cost_cents
  end

  # Locked so a webhook and nightly job arriving together can't each create one.
  def call
    @membership.with_lock do
      invoices.active_on(@covering).first || create_invoice
    end
  end

  private

  def invoices
    @membership.membership_invoices
  end

  def create_invoice
    return if @membership.cancelled?

    invoice = invoices.new(
      start_date: @covering,
      end_date: @covering + Membership::INVOICE_PERIOD - 1.day,
      cost_cents: @cost_cents || @membership.cost_cents || Membership::ANNUAL_COST_CENTS
    )

    invoice if invoice.save
  end
end
