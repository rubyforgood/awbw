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

  puts "  Payment seeds complete!"
