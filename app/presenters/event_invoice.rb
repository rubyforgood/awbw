# Normalizes the data needed to render an event invoice from either source it
# can be generated for: a single person's EventRegistration, or an
# organization's bulk-payment FormSubmission. Both resolve to the same shape
# (bill-to, attention, line items, total) so one view renders both.
class EventInvoice
  ISSUER_NAME = "A Window Between Worlds".freeze
  ISSUER_ADDRESS_LINES = [ "1029 1/2 W 24th St", "Los Angeles, CA 90007" ].freeze
  ISSUER_EMAIL = "info@awbw.org".freeze
  PAYABLE_TO_NOTE = "Please make checks payable to A Window Between Worlds".freeze

  LineItem = Struct.new(:date, :description, :quantity, :unit_price_cents, :details, keyword_init: true) do
    def amount_cents
      unit_price_cents.to_i * quantity.to_i
    end

    def details
      self[:details] || []
    end
  end

  # One applied payment or credit (scholarship/discount) that reduces the balance
  # due. Payments are itemized by method (Cash/Check/Credit card), with the check
  # number as a reference; scholarships/discounts show their kind.
  Entry = Struct.new(:date, :method, :reference, :amount_cents, keyword_init: true)

  attr_reader :event, :number, :date, :reference, :client_id,
              :bill_to_name, :bill_to_address_lines, :bill_to_email,
              :attention, :line_items, :entries, :amount_applied_cents

  # One registration → one attendee billed at the event cost, less anything
  # already applied (payments, scholarships, discounts) so the invoice reflects
  # the balance actually due. The registrant's snapshotted organization (if any)
  # is the bill-to; otherwise bill the person.
  def self.from_registration(registration)
    event = registration.event
    registrant = registration.registrant
    organization = registration.organizations.first
    addressable = organization || registrant
    allocations = registration.allocations.includes(:source).order(:created_at)

    new(
      event: event,
      number: "R-#{registration.id}",
      date: registration.created_at.to_date,
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
      amount_applied_cents: allocations.sum(&:amount)
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

  # A blank invoice template carrying only the event's content (one attendee at
  # the event cost). The bill-to and attention are left empty to be filled in.
  def self.from_event(event)
    new(
      event: event,
      number: nil,
      date: Date.current,
      client_id: nil,
      bill_to_name: nil,
      bill_to_address_lines: [],
      bill_to_email: nil,
      attention: nil,
      line_items: [
        LineItem.new(
          date: nil,
          description: event.title,
          quantity: 1,
          unit_price_cents: event.cost_cents.to_i
        )
      ]
    )
  end

  # A bulk payment bills the payer's organization for every attendee submitted.
  # The form captures the payer/org as free text (no Organization record), so
  # there is no structured address to show.
  def self.from_bulk_payment(submission)
    event = submission.resolved_event
    answers = submission.answers_by_identifier
    payer = submission.person
    payer_name = [ answers["payer_first_name"], answers["payer_last_name"] ]
      .map(&:presence).compact.join(" ").presence || payer&.full_name
    quantity = [ submission.bulk_payment_attendee_count, 1 ].max

    new(
      event: event,
      number: "B-#{submission.id}",
      date: submission.created_at.to_date,
      client_id: submission.id,
      bill_to_name: answers["payer_organization"].presence || payer_name,
      bill_to_address_lines: [],
      bill_to_email: answers["payer_email"].presence || payer&.preferred_email,
      attention: payer_name,
      line_items: [
        LineItem.new(
          date: submission.created_at.to_date,
          description: event&.title,
          quantity: quantity,
          unit_price_cents: event&.cost_cents.to_i,
          details: attendee_detail_lines(submission)
        )
      ]
    )
  end

  # One "First Last — email" line per attendee the payer entered on the bulk
  # payment form, so the invoice spells out who the payment covers. Either field
  # may be blank, so each line falls back to whichever part is present.
  def self.attendee_detail_lines(submission)
    submission.bulk_payment_attendees.filter_map do |attendee|
      name = [ attendee["first_name"], attendee["last_name"] ]
        .map { |part| part.to_s.strip.presence }.compact.join(" ")
      email = attendee["email"].to_s.strip.presence
      [ name.presence, email ].compact.join(" — ").presence
    end
  end
  private_class_method :attendee_detail_lines

  def initialize(event:, number:, date:, client_id:, bill_to_name:,
                 bill_to_address_lines:, bill_to_email:, attention:, line_items:,
                 reference: nil, entries: [], amount_applied_cents: 0)
    @event = event
    @number = number
    @date = date
    @client_id = client_id
    @bill_to_name = bill_to_name
    @bill_to_address_lines = bill_to_address_lines
    @bill_to_email = bill_to_email
    @attention = attention
    @line_items = line_items
    @reference = reference
    @entries = entries
    @amount_applied_cents = amount_applied_cents
  end

  def total_cents
    line_items.sum(&:amount_cents)
  end

  # The full charge net of everything already applied, floored at zero — what the
  # invoice actually asks the payer for. Equals the total when nothing's applied
  # (the blank template and bulk-payment invoices, which carry no allocations).
  def balance_due_cents
    [ total_cents - amount_applied_cents, 0 ].max
  end

  def issuer_name = ISSUER_NAME
  def issuer_address_lines = ISSUER_ADDRESS_LINES
  def issuer_email = ISSUER_EMAIL
  def payable_to_note = PAYABLE_TO_NOTE

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
