class InvoicePresenter
  attr_reader :invoice

  def initialize(invoice)
    @invoice = invoice
  end

  def bill_to_name = show_invoicee? ? invoicee_name : nil
  def invoicee = invoice.invoicee
  def bill_to_address_lines = show_address? ? address_lines(invoice.bill_to_address) : []
  def additional_info = invoice.bill_to_additional_info.to_s.strip.presence
  def show_invoicee? = !invoice.hide_invoicee?
  def show_address? = !invoice.hide_address?
  def show_bill_to? = show_invoicee? || show_address? || additional_info.present?
  def attention = invoice.attention_person&.full_name
  def line_items = invoice.invoice_line_items.order(:id)
  def total_cents = invoice.total_cents
  def number = invoice.number
  def date = invoice.date
  def invoicee_id = invoicee&.id
  def reference = nil

  def issuer = @issuer ||= InvoiceIssuer.current
  def issuer_name = issuer.name
  def issuer_address_lines = issuer.address_lines
  def issuer_email = issuer.email
  def payable_to_note = issuer.payable_to_note

  def amount_applied_cents = 0
  def balance_due_cents = total_cents

  private

  def invoicee_name
    return unless invoicee
    invoicee.respond_to?(:full_name) ? invoicee.full_name : invoicee.name
  end

  def address_lines(address)
    return [] unless address

    city_line = [ address.city.presence,
                  [ address.state.presence, address.zip_code.presence ].compact.join(" ").presence ]
      .compact.join(", ")
    [ address.street_address.presence, city_line.presence ].compact
  end
end
