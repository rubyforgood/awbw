# Cross-event revenue report: one row per event summarizing the money behind it
# — registration payments collected, continuing-education fees owed, scholarships
# split by whether a funder/grant backs them, what's still outstanding, and the
# rolled-up totals. Reuses EventDashboard per event so the figures reconcile with
# each event's dashboard.
#
# Continuing education is not yet collected anywhere (no payment/allocation
# tracking exists), so CE fees are reported as the amount *owed*
# ($25 x hours requested) with $0 received — the full CE fee therefore lands in
# the outstanding column.
class EventRevenueReport
  CE_HOURLY_RATE_CENTS = EventRegistration::CE_HOURLY_RATE_DOLLARS * 100

  Row = Struct.new(
    :event,
    :registration_payments_cents,
    :ce_fees_cents,
    :ce_paid_cents,
    :funded_scholarship_cents,
    :unfunded_scholarship_cents,
    :registration_outstanding_cents,
    keyword_init: true
  ) do
    # Everything still owed: registration fees not yet covered (event cost minus
    # payments, discounts, and scholarships) plus the unpaid CE fee.
    def outstanding_cents
      registration_outstanding_cents + ce_fees_cents - ce_paid_cents
    end

    # All revenue tied to the event: registrant payments, CE fees, and both
    # funded and unfunded scholarships.
    def total_monies_cents
      registration_payments_cents + ce_fees_cents + funded_scholarship_cents + unfunded_scholarship_cents
    end

    # Total revenue excluding scholarships with no funder behind them — the comped
    # cost that never becomes real money.
    def total_monies_excluding_unfunded_cents
      total_monies_cents - unfunded_scholarship_cents
    end
  end

  def initialize(events)
    @events = events
  end

  def rows
    @rows ||= @events.map { |event| build_row(event) }
  end

  def registration_payments_cents = sum_rows(:registration_payments_cents)
  def ce_fees_cents = sum_rows(:ce_fees_cents)
  def ce_paid_cents = sum_rows(:ce_paid_cents)
  def funded_scholarship_cents = sum_rows(:funded_scholarship_cents)
  def unfunded_scholarship_cents = sum_rows(:unfunded_scholarship_cents)
  def outstanding_cents = sum_rows(:outstanding_cents)
  def total_monies_cents = sum_rows(:total_monies_cents)
  def total_monies_excluding_unfunded_cents = sum_rows(:total_monies_excluding_unfunded_cents)

  private

  def build_row(event)
    dashboard = EventDashboard.new(event)
    Row.new(
      event: event,
      registration_payments_cents: dashboard.received_cents,
      ce_fees_cents: ce_fees_cents_for(event),
      ce_paid_cents: 0,
      funded_scholarship_cents: dashboard.funded_scholarship_cents,
      unfunded_scholarship_cents: dashboard.unfunded_scholarship_cents,
      registration_outstanding_cents: dashboard.outstanding_cents
    )
  end

  # CE fee owed across this event's active registrants: $25 per requested hour.
  def ce_fees_cents_for(event)
    hours = event.event_registrations.active.where(ce_credit_requested: true).sum(:ce_hours_requested)
    hours.to_i * CE_HOURLY_RATE_CENTS
  end

  def sum_rows(attribute)
    rows.sum { |row| row.public_send(attribute) }
  end
end
