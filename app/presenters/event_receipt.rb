# Normalizes the data needed to render a receipt for either source: a single
# EventRegistration or a bulk-payment FormSubmission. Mirrors EventInvoice (same
# bill-to/attention/line-item shape) and adds a payment ledger.
#
# The two differ in how the summary reads. A registration receipt settles a
# balance — it lists every allocation and reconciles to $0 due (only generated
# once paid in full, see EventRegistration#receipt_available?). A bulk payment
# has no owed-balance concept; its receipt simply records the amount paid, so it
# skips the total-charged/balance-due framing (balance_settlement: false).
class EventReceipt
  ISSUER_NAME = "A Window Between Worlds".freeze
  ISSUER_ADDRESS_LINES = [ "1029 1/2 W 24th St", "Los Angeles, CA 90007" ].freeze
  ISSUER_EMAIL = "info@awbw.org".freeze
  THANK_YOU_NOTE = "Payment received in full — thank you. Please retain this receipt for your records.".freeze
  PAYMENT_RECEIVED_NOTE = "Payment received — thank you. Please retain this receipt for your records.".freeze

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
      method: AllocationLedgerLabel.method_label(allocation),
      reference: AllocationLedgerLabel.reference_for(allocation),
      amount_cents: allocation.amount
    )
  end
  private_class_method :entry_for

  # One bulk-payment FormSubmission → the event charge for every attendee as a
  # single line item, and the payer's one payment as the ledger entry. Billed to
  # whoever the connected Payment records as the payer (respecting payer_type) —
  # NOT the form submitter, who may differ once an admin records the payment
  # against a different person/organization. Only generated once a payment is on
  # file (see FormSubmission#bulk_payment_receipt_available?).
  def self.from_bulk_payment(submission)
    event = submission.resolved_event
    payment = submission.payment
    payer = payment&.payer
    # The org, if the org paid; the individual is the payer when a person paid,
    # otherwise the org's contact person recorded on the payment.
    organization = payer.is_a?(Organization) ? payer : nil
    individual = payer.is_a?(Person) ? payer : payment&.person
    quantity = [ submission.bulk_payment_attendee_count, 1 ].max

    new(
      event: event,
      number: "RCPT-B-#{submission.id}",
      date: (payment&.created_at || submission.created_at).to_date,
      client_id: payer&.id,
      bill_to_name: organization&.name.presence || individual&.full_name,
      bill_to_address_lines: address_lines_for(payer),
      bill_to_email: organization&.email.presence || individual&.preferred_email,
      attention: individual&.full_name,
      line_items: [
        LineItem.new(
          date: submission.created_at.to_date,
          description: event&.title,
          quantity: quantity,
          unit_price_cents: event&.cost_cents.to_i
        )
      ],
      entries: payment ? [ entry_for_payment(payment) ] : [],
      amount_paid_cents: payment&.amount_cents.to_i,
      balance_cents: 0,
      balance_settlement: false
    )
  end

  def self.entry_for_payment(payment)
    Entry.new(
      date: payment.created_at.to_date,
      method: AllocationLedgerLabel.payment_method_label(payment),
      reference: AllocationLedgerLabel.payment_reference(payment),
      amount_cents: payment.amount_cents
    )
  end
  private_class_method :entry_for_payment

  def initialize(event:, number:, date:, client_id:, bill_to_name:,
                 bill_to_address_lines:, bill_to_email:, attention:, line_items:,
                 entries:, amount_paid_cents:, balance_cents:, balance_settlement: true)
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
    @balance_settlement = balance_settlement
  end

  def total_cents
    line_items.sum(&:amount_cents)
  end

  def paid_in_full?
    balance_cents.to_i.zero?
  end

  # A registration receipt settles a balance (total charged → $0 due); a bulk
  # payment receipt has no such concept and just records the amount paid. The
  # view branches on this to drop the total-charged/balance-due framing.
  def settles_balance?
    @balance_settlement
  end

  def issuer_name = ISSUER_NAME
  def issuer_address_lines = ISSUER_ADDRESS_LINES
  def issuer_email = ISSUER_EMAIL
  def thank_you_note = settles_balance? ? THANK_YOU_NOTE : PAYMENT_RECEIVED_NOTE

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
