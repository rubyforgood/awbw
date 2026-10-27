class MembershipInvoiceReceipt
  THANK_YOU_NOTE = "Payment received in full — thank you. Please retain this receipt for your records.".freeze

  LineItem = Struct.new(:date, :description, :quantity, :unit_price_cents, keyword_init: true) do
    def amount_cents
      unit_price_cents.to_i * quantity.to_i
    end
  end

  Entry = Struct.new(:date, :method, :reference, :amount_cents, keyword_init: true)

  attr_reader :invoice

  def initialize(invoice)
    @invoice = invoice
  end

  def number = "MR-#{invoice.id}"
  def date = (allocations.last&.created_at || invoice.created_at).to_date
  def client_id = invoice.person.id

  delegate :bill_to_name, :bill_to_address_lines, :additional_info,
           :attention, :show_bill_to?, to: :presenter

  def line_items
    [
      LineItem.new(
        date: invoice.start_date,
        description: MembershipInvoicePresenter::DESCRIPTION,
        quantity: 1,
        unit_price_cents: invoice.cost_cents.to_i
      )
    ]
  end

  def entries
    allocations.map do |allocation|
      Entry.new(
        date: allocation.created_at.to_date,
        method: AllocationLedgerLabel.method_label(allocation),
        reference: AllocationLedgerLabel.reference_for(allocation),
        amount_cents: allocation.amount
      )
    end
  end

  def total_cents = line_items.sum(&:amount_cents)
  def amount_paid_cents = allocations.sum(&:amount)
  def balance_cents = [ total_cents - amount_paid_cents, 0 ].max
  def paid_in_full? = balance_cents.zero?

  def issuer = @issuer ||= InvoiceIssuer.current
  def issuer_name = issuer.name
  def issuer_address_lines = issuer.address_lines
  def issuer_email = issuer.email
  def thank_you_note = THANK_YOU_NOTE

  private

  def presenter = @presenter ||= MembershipInvoicePresenter.new(invoice)

  def allocations
    @allocations ||= invoice.allocations.includes(:source).order(:created_at).to_a
  end
end
