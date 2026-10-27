class MembershipInvoicePresenter
  LineItem = Struct.new(:date, :description, :quantity, :unit_price_cents, keyword_init: true) do
    def amount_cents
      unit_price_cents.to_i * quantity.to_i
    end
  end

  DESCRIPTION = "AWBW annual membership".freeze

  attr_reader :invoice

  def initialize(invoice)
    @invoice = invoice
  end

  def person = invoice.person
  def number = "M-#{invoice.id}"
  def date = invoice.created_at.to_date
  def reference = nil
  def client_id = person.id

  def invoicee = invoice.invoicee || person

  def bill_to_name
    return if invoice.hide_invoicee?

    invoicee.respond_to?(:full_name) ? invoicee.full_name : invoicee.name
  end

  def bill_to_address_lines
    return [] if invoice.hide_address?
    return invoice.bill_to_address.display_lines if invoice.bill_to_address

    Address.display_lines_for(invoicee)
  end

  def additional_info = invoice.bill_to_additional_info.to_s.strip.presence
  def attention = invoice.attention_person&.full_name
  def show_bill_to? = bill_to_name.present? || bill_to_address_lines.any? || additional_info.present?

  def line_items
    items = [ LineItem.new(date: invoice.start_date, description: DESCRIPTION, quantity: 1, unit_price_cents: invoice.cost_cents.to_i) ]
    discount = invoice.discount_sum
    items << LineItem.new(date: invoice.start_date, description: "Discount", quantity: 1, unit_price_cents: -discount) if discount.positive?
    items
  end

  def total_cents = [ line_items.sum(&:amount_cents), 0 ].max

  def issuer = @issuer ||= InvoiceIssuer.current
  def issuer_name = issuer.name
  def issuer_address_lines = issuer.address_lines
  def issuer_email = issuer.email
  def payable_to_note = issuer.payable_to_note
  def remittance_address_lines = issuer.remittance_address_lines
end
