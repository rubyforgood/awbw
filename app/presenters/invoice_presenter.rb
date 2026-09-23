class InvoicePresenter
  ISSUER_NAME = "A Window Between Worlds".freeze
  ISSUER_ADDRESS_LINES = [ "1029 1/2 W 24th St", "Los Angeles, CA 90007" ].freeze
  ISSUER_EMAIL = "info@awbw.org".freeze
  PAYABLE_TO_NOTE = "Please make checks payable to A Window Between Worlds".freeze

  attr_reader :invoice

  def initialize(invoice)
    @invoice = invoice
  end

  def bill_to_name = invoice.bill_to_name
  def bill_to_address_lines = invoice.bill_to_address.to_s.lines.map(&:strip).reject { |l| l.include?("@") }.presence || []
  def bill_to_email = invoice.bill_to_address.to_s.lines.grep(/@/).first
  def attention = invoice.attention_person&.compound_search_label&.dig(:label)
  def line_items = invoice.invoice_line_items.order(:id)
  def total_cents = invoice.total_cents
  def number = invoice.number
  def date = invoice.date
  def client_id = invoice.client_id
  def reference = nil
  def payable_to_note = PAYABLE_TO_NOTE

  def issuer_name = ISSUER_NAME
  def issuer_address_lines = ISSUER_ADDRESS_LINES
  def issuer_email = ISSUER_EMAIL

  def amount_applied_cents = 0
  def balance_due_cents = total_cents
end
