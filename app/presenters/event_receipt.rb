# Normalizes the data needed to render a paid-in-full receipt for a single
# EventRegistration. Mirrors EventInvoice (same bill-to/attention/line-item
# shape) but adds the allocation ledger that settled the balance and a summary
# that always reconciles to $0 due — a receipt is only generated once the
# registration is paid in full (see EventRegistration#receipt_available?).
class EventReceipt
  ISSUER_NAME = "A Window Between Worlds".freeze
  ISSUER_ADDRESS_LINES = [ "1029 1/2 W 24th St", "Los Angeles, CA 90007" ].freeze
  ISSUER_EMAIL = "info@awbw.org".freeze
  THANK_YOU_NOTE = "Payment received in full — thank you. Please retain this receipt for your records.".freeze

  # Friendly payment-method names for the ledger. Payment is an STI base whose
  # polymorphic source_type is always "Payment"; the concrete subclass tells us
  # how it was paid. Non-payment allocations (scholarships, discounts) fall back
  # to their humanized type.
  PAYMENT_METHOD_LABELS = {
    "CashPayment" => "Cash",
    "CheckPayment" => "Check",
    "ExternalProcessorPayment" => "Credit card",
    "FilemakerPayment" => "Payment"
  }.freeze

  LineItem = Struct.new(:date, :description, :quantity, :unit_price_cents, keyword_init: true) do
    def amount_cents
      unit_price_cents.to_i * quantity.to_i
    end
  end

  Entry = Struct.new(:date, :method, :reference, :amount_cents, keyword_init: true)

  attr_reader :event, :number, :date, :client_id,
              :bill_to_name, :bill_to_address_lines, :bill_to_email,
              :attention, :line_items, :entries, :amount_paid_cents, :balance_cents

  # One registration → the event charge as a line item, every allocation that
  # settled it as a ledger entry, and a balance that reconciles to zero. The
  # snapshotted organization (if any) is the bill-to; otherwise bill the person.
  def self.from_registration(registration)
    event = registration.event
    registrant = registration.registrant
    organization = registration.organizations.first
    addressable = organization || registrant
    allocations = registration.allocations.includes(:source).order(:created_at)
    amount_paid_cents = allocations.sum(&:amount)

    new(
      event: event,
      number: "RCPT-#{registration.id}",
      date: (allocations.last&.created_at || registration.created_at).to_date,
      client_id: organization&.id || registrant.id,
      bill_to_name: organization&.name.presence || registrant.full_name,
      bill_to_address_lines: address_lines_for(addressable),
      bill_to_email: organization&.email.presence || registrant.preferred_email,
      attention: registrant.full_name,
      line_items: [
        LineItem.new(
          date: registration.created_at.to_date,
          description: event.title,
          quantity: 1,
          unit_price_cents: event.cost_cents.to_i
        )
      ],
      entries: allocations.map { |allocation| entry_for(allocation) },
      amount_paid_cents: amount_paid_cents,
      balance_cents: [ event.cost_cents.to_i - amount_paid_cents, 0 ].max
    )
  end

  def self.entry_for(allocation)
    Entry.new(
      date: allocation.created_at.to_date,
      method: method_label(allocation),
      reference: reference_for(allocation),
      amount_cents: allocation.amount
    )
  end
  private_class_method :entry_for

  def self.method_label(allocation)
    if allocation.source_type == Payment.polymorphic_name
      PAYMENT_METHOD_LABELS[allocation.source&.class&.name] || "Payment"
    else
      allocation.source_type.underscore.humanize
    end
  end
  private_class_method :method_label

  # Check number, when the payment was a check — standard receipt detail so the
  # payer can reconcile it against their own records.
  def self.reference_for(allocation)
    source = allocation.source
    return unless source.is_a?(CheckPayment) && source.check_number.present?
    "Check ##{source.check_number}"
  end
  private_class_method :reference_for

  def initialize(event:, number:, date:, client_id:, bill_to_name:,
                 bill_to_address_lines:, bill_to_email:, attention:, line_items:,
                 entries:, amount_paid_cents:, balance_cents:)
    @event = event
    @number = number
    @date = date
    @client_id = client_id
    @bill_to_name = bill_to_name
    @bill_to_address_lines = bill_to_address_lines
    @bill_to_email = bill_to_email
    @attention = attention
    @line_items = line_items
    @entries = entries
    @amount_paid_cents = amount_paid_cents
    @balance_cents = balance_cents
  end

  def total_cents
    line_items.sum(&:amount_cents)
  end

  def paid_in_full?
    balance_cents.to_i.zero?
  end

  def issuer_name = ISSUER_NAME
  def issuer_address_lines = ISSUER_ADDRESS_LINES
  def issuer_email = ISSUER_EMAIL
  def thank_you_note = THANK_YOU_NOTE

  def self.address_lines_for(addressable)
    return [] unless addressable.respond_to?(:addresses)

    address = addressable.addresses.active.first
    return [] unless address

    city_line = [ address.city.presence,
                  [ address.state.presence, address.zip_code.presence ].compact.join(" ").presence ]
      .compact.join(", ")
    [ address.street_address.presence, city_line.presence ].compact
  end
  private_class_method :address_lines_for
end
