# Payment seeds (dev-only) - run on their own via `rake db:seed:payments`, or
# as part of `rake db:seed:dev`.

puts "Seeding Payments, Allocations, and Refunds..."

payment_ids_start = Payment.maximum(:id) || 0
allocation_ids_start = Allocation.maximum(:id) || 0
refund_ids_start = Refund.maximum(:id) || 0
event_reg_ids_start = EventRegistration.maximum(:id) || 0

Refund.where("id > ?", refund_ids_start).delete_all
Allocation.where("id > ?", allocation_ids_start).delete_all
Payment.where("id > ?", payment_ids_start).delete_all
EventRegistration.where("id > ?", event_reg_ids_start).delete_all

event_cost_cents = 150000

bob = Person.find_or_create_by!(email: "bob.payment@seed.example.com") do |p|
  p.first_name = "Bob"
  p.last_name = "Barker"
end

alice = Person.find_or_create_by!(email: "alice.payment@seed.example.com") do |p|
  p.first_name = "Alice"
  p.last_name = "Test"
end

charlie = Person.find_or_create_by!(email: "charlie.payment@seed.example.com") do |p|
  p.first_name = "Charlie"
  p.last_name = "Test"
end

diana = Person.find_or_create_by!(email: "diana.payment@seed.example.com") do |p|
  p.first_name = "Diana"
  p.last_name = "Test"
end

eve = Person.find_or_create_by!(email: "eve.payment@seed.example.com") do |p|
  p.first_name = "Eve"
  p.last_name = "Test"
end

frank = Person.find_or_create_by!(email: "frank.payment@seed.example.com") do |p|
  p.first_name = "Frank"
  p.last_name = "Test"
end

gary = Person.find_or_create_by!(email: "gary.payment@seed.example.com") do |p|
  p.first_name = "Gary"
  p.last_name = "Test"
end

holly = Person.find_or_create_by!(email: "holly.payment@seed.example.com") do |p|
  p.first_name = "Holly"
  p.last_name = "Test"
end

iris = Person.find_or_create_by!(email: "iris.payment@seed.example.com") do |p|
  p.first_name = "Iris"
  p.last_name = "Test"
end

event = Event.find_or_create_by!(title: "Test Payments Workshop") do |e|
  e.start_date = 1.month.from_now.to_date
  e.end_date = 1.month.from_now.to_date + 2.days
  e.published = true
  e.cost_cents = event_cost_cents
end
event.update!(start_date: 1.month.from_now.to_date, end_date: 1.month.from_now.to_date + 2.days, published: true, cost_cents: event_cost_cents)

reg_bob = EventRegistration.find_or_create_by!(registrant: bob, event: event)
reg_alice = EventRegistration.find_or_create_by!(registrant: alice, event: event)
reg_charlie = EventRegistration.find_or_create_by!(registrant: charlie, event: event)
reg_diana = EventRegistration.find_or_create_by!(registrant: diana, event: event)
reg_eve = EventRegistration.find_or_create_by!(registrant: eve, event: event)
reg_frank = EventRegistration.find_or_create_by!(registrant: frank, event: event)
reg_gary = EventRegistration.find_or_create_by!(registrant: gary, event: event)
reg_iris = EventRegistration.find_or_create_by!(registrant: iris, event: event)

puts "  Payment made but allocation reverted)"
payment1 = CashPayment.find_or_create_by!(
  person: bob,
  amount_cents: event_cost_cents
) do |p|
  p.created_at = 5.days.ago
end
original_allocation1 = Allocation.create!(
  source: payment1,
  allocatable: reg_bob,
  amount: event_cost_cents,
  created_at: 5.days.ago
)
reversal_allocation1 = Allocation.create!(
  source: payment1,
  allocatable: reg_bob,
  amount: -event_cost_cents,
  created_at: 4.days.ago
)
original_allocation1.update!(reverted_id: reversal_allocation1.id)

puts "  Overpayment with full allocation (Alice pays $6000, covers 4 people)"
payment2 = CashPayment.find_or_create_by!(
  person: alice,
  amount_cents: 600000
) do |p|
  p.created_at = 4.days.ago
end
Allocation.find_or_create_by!(source: payment2, allocatable: reg_alice, amount: event_cost_cents) { |a| a.created_at = 4.days.ago }
Allocation.find_or_create_by!(source: payment2, allocatable: reg_charlie, amount: event_cost_cents) { |a| a.created_at = 4.days.ago }
Allocation.find_or_create_by!(source: payment2, allocatable: reg_diana, amount: event_cost_cents) { |a| a.created_at = 4.days.ago }
Allocation.find_or_create_by!(source: payment2, allocatable: reg_eve, amount: event_cost_cents) { |a| a.created_at = 4.days.ago }

puts "  Payment with remaining available ($2000 payment, $1500 allocated, $500 remaining)"
payment3 = CashPayment.find_or_create_by!(
  person: frank,
  amount_cents: 200000
) do |p|
  p.created_at = 3.days.ago
end
Allocation.find_or_create_by!(
  source: payment3,
  allocatable: reg_frank,
  amount: 150000
) do |a|
  a.created_at = 3.days.ago
end

puts "  Full refund ($1500 payment, fully allocated, fully refunded)"
payment4 = CashPayment.find_or_create_by!(
  person: gary,
  amount_cents: event_cost_cents
) do |p|
  p.created_at = 2.days.ago
end
original_alloc = Allocation.create!(
  source: payment4,
  allocatable: reg_gary,
  amount: event_cost_cents,
  created_at: 2.days.ago
)
reversal_alloc = Allocation.create!(
  source: payment4,
  allocatable: reg_gary,
  amount: -event_cost_cents,
  created_at: 1.day.ago
)
original_alloc.update!(reverted_id: reversal_alloc.id)
Refund.create!(
  refundable: payment4,
  recipient: gary,
  amount_cents: event_cost_cents,
  method: "check",
  created_at: 1.day.ago
)

puts "  Creating Scenario 8: Payment with no allocations ($10000, full amount remaining)"
CashPayment.find_or_create_by!(
  person: holly,
  amount_cents: 1000000
) do |p|
  p.created_at = 7.days.ago
end

puts "  Partial payment"
payment9 = CashPayment.find_or_create_by!(
  person: iris,
  amount_cents: 100000
) do |p|
  p.created_at = 3.days.ago
end
Allocation.find_or_create_by!(
  source: payment9,
  allocatable: reg_iris,
  amount: 100000
) do |a|
  a.created_at = 3.days.ago
end

puts "Creating Scholarships, Payments, and Allocations for dev events…"
# Funds registrations on the paid dev events with real money + scholarship
# records so the event overview dashboard (registrants / received / outstanding
# / scholarships) shows meaningful numbers. The events, people, and registrations
# are created in db/seeds/dev/dummy.rb, so this only fills in the financial side
# when the dummy seeds have already run (e.g. via `rake db:seed:dev`); on its own
# `rake db:seed:payments` simply skips events that aren't present.
#
# Each registration is funded at most once — the guard skips any registration
# that already has allocations, so the section is safe to re-run.

amy_person = User.find_by(email: "amy.user@example.com")&.person
maria_j = Person.find_by(first_name: "Maria", last_name: "Johnson")
anna_g = Person.find_by(first_name: "Anna", last_name: "Garcia")
sarah_s = Person.find_by(first_name: "Sarah", last_name: "Smith")
jessica_b = Person.find_by(first_name: "Jessica", last_name: "Brown")
mario_j = Person.find_by(first_name: "Mario", last_name: "Johnson")
angel_g = Person.find_by(first_name: "Angel", last_name: "Garcia")

facilitator_training = Event.find_by(title: "AWBW Facilitator Training")
trauma_training = Event.find_by(title: "Facilitator Training: Trauma-Informed Art Practices")
mindful_art = Event.find_by(title: "Mindful Art for Survivors Workshop")

org_payer = Organization.find_by(name: "Angel Step Inn")

# Mirrors ScholarshipsController: build the scholarship with a $0 allocation,
# then set the amount + tasks_completed so sync_allocation_amount funds the
# allocation only when the recipient's tasks are complete.
award_scholarship = ->(registration, amount_cents:, tasks_completed:) do
  scholarship = Scholarship.new(recipient: registration.registrant)
  scholarship.build_allocation(allocatable: registration, amount: 0)
  scholarship.save!
  scholarship.update!(amount_cents: amount_cents, tasks_completed: tasks_completed)
  scholarship
end

# payer is a Person or an Organization; kind is :cash or :check.
record_payment = ->(registration, payer:, amount_cents:, kind: :cash) do
  payer_attrs = payer.is_a?(Organization) ? { organization: payer } : { person: payer }
  created_at = rand(3..30).days.ago
  payment = case kind
  when :check
    CheckPayment.create!(**payer_attrs, amount_cents: amount_cents, check_number: "CHK-#{rand(10_000..99_999)}", created_at: created_at)
  else
    CashPayment.create!(**payer_attrs, amount_cents: amount_cents, created_at: created_at)
  end
  Allocation.create!(source: payment, allocatable: registration, amount: amount_cents, created_at: created_at)
end

# Applies a discount to a registration — a Discount-sourced allocation that
# reduces the amount owed (drives the "Discounted $X due" / "Nothing owed" chip).
record_discount = ->(registration, amount_cents:) do
  created_at = rand(3..30).days.ago
  discount = Discount.create!(amount_cents: amount_cents)
  Allocation.create!(source: discount, allocatable: registration, amount: amount_cents, created_at: created_at)
end

# Funds a registration once. `scholarship`, `discount`, and `payments` describe what to build.
fund_registration = ->(event, person, scholarship: nil, discount: nil, payments: []) do
  return unless event && person
  registration = EventRegistration.find_by(event: event, registrant: person)
  return unless registration
  return if registration.allocations.exists?

  award_scholarship.(registration, **scholarship) if scholarship
  record_discount.(registration, **discount) if discount
  payments.each { |payment| record_payment.(registration, **payment) }
end

# --- AWBW Facilitator Training ($150) ---
# Amy: pending scholarship (tasks incomplete → $0 allocated) + partial cash → still owes
fund_registration.(facilitator_training, amy_person,
  scholarship: { amount_cents: 10_000, tasks_completed: false },
  payments: [ { payer: amy_person, amount_cents: 5_000, kind: :cash } ])
# Maria: partial cash → still owes, intends to pay the rest
fund_registration.(facilitator_training, maria_j,
  payments: [ { payer: maria_j, amount_cents: 5_000, kind: :cash } ])
# Anna: partial check from her organization → still owes, intends to pay the rest (org-payer scenario)
fund_registration.(facilitator_training, anna_g,
  payments: [ { payer: org_payer || anna_g, amount_cents: 5_000, kind: :check } ])
# Mario: partial cash → still owes
fund_registration.(facilitator_training, mario_j,
  payments: [ { payer: mario_j, amount_cents: 5_000, kind: :cash } ])

# --- Facilitator Training: Trauma-Informed Art Practices ($120) ---
# Sarah: paid in full by check
fund_registration.(trauma_training, sarah_s,
  payments: [ { payer: sarah_s, amount_cents: 12_000, kind: :check } ])
# Jessica: completed scholarship ($80) + cash for the remainder → paid in full
fund_registration.(trauma_training, jessica_b,
  scholarship: { amount_cents: 8_000, tasks_completed: true },
  payments: [ { payer: jessica_b, amount_cents: 4_000, kind: :cash } ])
# Angel: partial cash → still owes
fund_registration.(trauma_training, angel_g,
  payments: [ { payer: angel_g, amount_cents: 6_000, kind: :cash } ])

# --- Mindful Art for Survivors Workshop ($50) ---
# Amy: paid in full by cash
fund_registration.(mindful_art, amy_person,
  payments: [ { payer: amy_person, amount_cents: 5_000, kind: :cash } ])

# --- AWBW Facilitator Training ($1,500): discount + multi-payment chip states ---
# Getting more than one payment from a single registrant is rare, so only Nina
# keeps that shape (it still exercises multi-payment allocations). The rest are
# single-payment, and three carry a Discount so the payment-status column shows
# the "Discounted $X due" / fully-discounted "Nothing owed" chips. Amounts target
# the event's real $1,500 cost.
register_with_payments = ->(event, first_name:, last_name:, email:, scholarship: nil, discount: nil, payments: []) do
  return unless event
  person = Person.find_or_create_by!(email: email) do |p|
    p.first_name = first_name
    p.last_name = last_name
  end
  registration = EventRegistration.find_or_create_by!(registrant: person, event: event)
  return registration if registration.allocations.exists?

  award_scholarship.(registration, **scholarship) if scholarship
  record_discount.(registration, **discount) if discount
  payments.each { |payment| record_payment.(registration, **{ payer: person }.merge(payment)) }
  registration
end

# Recreate the demo registrants from scratch each run so re-seeding refreshes
# their scenarios (e.g. when the set of multipay/discount examples changes).
# Drop their registrations (cascades the allocations) and payments before the
# person, since payments reference the person without a destroy cascade.
Person.where("email LIKE ? OR email LIKE ?",
  "%.multipay@seed.example.com", "%.discount@seed.example.com").find_each do |demo_person|
  demo_person.event_registrations.destroy_all
  Payment.where(person: demo_person).destroy_all
  demo_person.destroy
end

# Nina: the one multi-payment registrant — paid in full via cash $1,000 + check $500
register_with_payments.(facilitator_training,
  first_name: "Nina", last_name: "Multipay", email: "nina.multipay@seed.example.com",
  payments: [
    { amount_cents: 100_000, kind: :cash },
    { amount_cents: 50_000, kind: :check }
  ])
# Dana: $300 discount, no payment → still owes $1,200 ("Discounted $1200.00 due")
register_with_payments.(facilitator_training,
  first_name: "Dana", last_name: "Discount", email: "dana.discount@seed.example.com",
  discount: { amount_cents: 30_000 })
# Dexter: fully discounted ($1,500) → "Nothing owed"
register_with_payments.(facilitator_training,
  first_name: "Dexter", last_name: "Discount", email: "dexter.discount@seed.example.com",
  discount: { amount_cents: 150_000 })
# Delia: $500 discount + single $200 cash payment → still owes $800 ("Discounted $800.00 due")
register_with_payments.(facilitator_training,
  first_name: "Delia", last_name: "Discount", email: "delia.discount@seed.example.com",
  discount: { amount_cents: 50_000 },
  payments: [ { amount_cents: 20_000, kind: :cash } ])

# Bulk payments for the flagship event are seeded separately in
# db/seeds/dev/bulk_payments.rb, which reproduces the real production channels
# (Stripe-webhook ExternalProcessorPayment, staff-logged cash/check, and pending)
# across the full matrix of allocation states, using dedicated demo people so
# those states stay clean and don't collide with the registrants funded above.

[ facilitator_training, trauma_training, mindful_art ].compact.each do |event|
  dashboard = EventDashboard.new(event)
  puts "  #{event.title}: #{dashboard.registrant_count} registrants, " \
       "received #{dashboard.received_cents / 100.0}, outstanding #{dashboard.outstanding_cents / 100.0}, " \
       "scholarships #{dashboard.scholarship_total_cents / 100.0} (#{dashboard.scholarship_recipient_count})"
end

puts "  Payment seeds complete!"
