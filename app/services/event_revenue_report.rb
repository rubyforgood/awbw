# Cross-event revenue report: one row per paid event summarizing the money behind
# it — registration payments collected, projected continuing-education revenue,
# scholarships split by whether a funder/grant backs them, what's still
# outstanding, and the rolled-up totals. Reuses EventDashboard per event so the
# figures reconcile with each event's dashboard.
#
# Continuing education is not yet collected anywhere (no payment/allocation
# tracking exists), so CE is reported as a *projected* amount — $25 x hours
# requested — counted as revenue rather than outstanding.
class EventRevenueReport
  CE_HOURLY_RATE_CENTS = EventRegistration::CE_HOURLY_RATE_DOLLARS * 100

  Row = Struct.new(
    :event,
    :registration_payments_cents,
    :ce_projected_cents,
    :funded_scholarship_cents,
    :unfunded_scholarship_cents,
    :registration_outstanding_cents,
    keyword_init: true
  ) do
    # Registration fees not yet covered (event cost minus payments, discounts,
    # and scholarships). CE is excluded — it's reported as projected revenue.
    def outstanding_cents
      registration_outstanding_cents
    end

    # All revenue tied to the event: registrant payments, projected CE, and both
    # funded and unfunded scholarships.
    def total_monies_cents
      registration_payments_cents + ce_projected_cents + funded_scholarship_cents + unfunded_scholarship_cents
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
  def ce_projected_cents = sum_rows(:ce_projected_cents)
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
      ce_projected_cents: ce_projected_cents_for(event),
      funded_scholarship_cents: dashboard.funded_scholarship_cents,
      unfunded_scholarship_cents: dashboard.unfunded_scholarship_cents,
      registration_outstanding_cents: dashboard.outstanding_cents
    )
  end

  # Projected CE revenue across this event's active registrants: $25 per
  # requested hour. Not collected yet — there's no CE payment tracking.
  def ce_projected_cents_for(event)
    hours = event.event_registrations.active.where(ce_credit_requested: true).sum(:ce_hours_requested)
    hours.to_i * CE_HOURLY_RATE_CENTS
  end

  def sum_rows(attribute)
    rows.sum { |row| row.public_send(attribute) }
  end
end
