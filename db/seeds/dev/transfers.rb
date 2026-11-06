# Transfer seeds (dev-only) — run on their own via `rake db:seed:transfers`, or as
# part of `rake db:seed:dev`. Three registrants who moved between two $450 events,
# plus a payment-gated callout on the new event to show access unlocking:
#   * Splitpaid: money on both registrations clears the balance.
#   * Intends: nothing paid, for trying the Intends to pay toggle on the new registration.
#   * Partial: an earlier payment on the old registration, with a balance left to pay.

puts "Creating transferred registrants…"

event_for = lambda do |title, start_date|
  Event.find_or_create_by!(title: title) do |event|
    event.start_date = start_date
    event.end_date = start_date + 2.hours
    event.cost_cents = 45_000
    event.published = true
  end
end
old_event = event_for.call("Transfer demo: original training", 2.weeks.from_now)
new_event = event_for.call("Transfer demo: new training", 6.weeks.from_now)

BuiltinCallouts.seed(new_event)
new_event.registration_ticket_callouts.find_or_create_by!(title: "Training info (paid only)") do |callout|
  callout.callout_type = "reference"
  callout.payment_access_gated = true
  callout.hidden = false
end

transfer = lambda do |first_name, old_paid:, new_paid:|
  person = Person.find_or_create_by!(email: "transfer.#{first_name.downcase}@example.com") do |record|
    record.first_name = first_name
    record.last_name = "Transferdemo"
  end
  source = EventRegistration.find_or_create_by!(registrant: person, event: old_event)
  incoming = EventRegistration.find_or_create_by!(registrant: person, event: new_event)
  incoming.update!(transferred_from_registration: source)
  source.update!(status: "transferred_out")

  { source => old_paid, incoming => new_paid }.each do |registration, cents|
    next if cents.zero? || registration.allocations.exists?

    payment = CashPayment.create!(person: person, amount_cents: cents)
    Allocation.create!(source: payment, allocatable: registration, amount: cents)
  end
end

transfer.call("Splitpaid", old_paid: 15_000, new_paid: 30_000)
transfer.call("Intends", old_paid: 0, new_paid: 0)
transfer.call("Partial", old_paid: 15_000, new_paid: 0)
