class InvoicePresenter
  ISSUER_NAME = "A Window Between Worlds".freeze
  ISSUER_ADDRESS_LINES = [ "1029 1/2 W 24th St", "Los Angeles, CA 90007" ].freeze
  ISSUER_EMAIL = "info@awbw.org".freeze
  PAYABLE_TO_NOTE = "Please make checks payable to A Window Between Worlds".freeze

  attr_reader :invoice

  def initialize(invoice)
    @invoice = invoice
  end

  def bill_to_name = invoicee&.respond_to?(:full_name) ? invoicee.full_name : invoicee&.name
  def invoicee = invoice.invoicee
  def bill_to_address_lines = invoice.bill_to_address.to_s.lines.map(&:strip).reject { |l| l.include?("@") }.presence || []
  def bill_to_email = invoice.bill_to_address.to_s.lines.grep(/@/).first
  def attention = invoice.attention_person&.full_name
  def line_items = invoice.invoice_line_items.order(:id)
  def total_cents = invoice.total_cents
  def number = invoice.number
  def date = invoice.date
  def invoicee_id = invoicee&.id
  def reference = nil
  def payable_to_note = PAYABLE_TO_NOTE

  def issuer_name = ISSUER_NAME
  def issuer_address_lines = ISSUER_ADDRESS_LINES
  def issuer_email = ISSUER_EMAIL

  def amount_applied_cents = 0
  def balance_due_cents = total_cents
end
