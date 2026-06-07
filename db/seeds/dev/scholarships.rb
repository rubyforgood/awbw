# Scholarship seeds (dev-only) — run on their own via `rake db:seed:scholarships`,
# or as part of `rake db:seed:dev`.
#
# Seeds scholarships on the paid dev events created in
# db/seeds/dev/events_management.rb, covering both states the dashboard needs to
# show:
#   * completed (tasks_completed: true) — Scholarship#sync_allocation_amount funds
#     the allocation, so the dollars are applied to the registration and count
#     toward the grand total ("Completed & allocated").
#   * pending (tasks_completed: false) — the allocation stays $0, so the award is
#     visible as "potentially awarded" but the registrant still owes the cost.
#
# A couple of scholarship + payment combos are seeded alongside the payments in
# db/seeds/dev/payments.rb (Amy, Jessica); this file fills out the flagship
# training with a full set of recipients. Looks up (rather than requires) the
# events and people, skips gracefully when absent, and skips any registration
# that already has a scholarship so it is safe to re-run.

puts "Seeding Scholarships for dev event registrations…"

facilitator_training = Event.find_by(title: "AWBW Facilitator Training")
trauma_training = Event.find_by(title: "Facilitator Training: Trauma-Informed Art Practices")
mindful_art = Event.find_by(title: "Mindful Art for Survivors Workshop")

angel_g = Person.find_by(first_name: "Angel", last_name: "Garcia")
samuel_s = Person.find_by(first_name: "Samuel", last_name: "Smith")

# Mirrors ScholarshipsController: build the scholarship with a $0 allocation, then
# set amount + tasks_completed so sync_allocation_amount funds the allocation only
# when the recipient's tasks are complete (completed → allocated; pending → $0).
award_scholarship = ->(registration, amount_cents:, tasks_completed:) do
  return unless registration
  return if registration.scholarships.exists?

  scholarship = Scholarship.new(recipient: registration.registrant)
  scholarship.build_allocation(allocatable: registration, amount: 0)
  scholarship.save!
  scholarship.update!(amount_cents: amount_cents, tasks_completed: tasks_completed)
end

award_for_person = ->(event, person, **opts) do
  return unless event && person
  award_scholarship.(EventRegistration.find_by(event: event, registrant: person), **opts)
end

# --- Flagship demo: AWBW Facilitator Training — 10 scholarships across its
# cohort, each a full or partial share of the registration fee, with roughly half
# completed (dollars allocated, counting toward the grand total) and half pending
# (awarded but unallocated). ---
if facilitator_training
  cost = facilitator_training.cost_cents
  # [ share of the registration fee, tasks_completed ]
  plan = [
    [ 1.0,  true ], [ 0.75, true ], [ 0.5,  true ], [ 1.0,  true ], [ 0.25, true ],
    [ 1.0,  false ], [ 0.5,  false ], [ 0.6,  false ], [ 0.4,  false ], [ 0.33, false ]
  ]
  active_regs = facilitator_training.event_registrations.active.to_a
  needed = [ 10 - active_regs.count { |reg| reg.scholarships.exists? }, 0 ].max
  # Only fund registrations with no allocations yet, so a full or partial award
  # fits within the event cost. A registrant who already paid has less room left,
  # and the allocation validation rejects allocating more than the remaining cost.
  candidates = active_regs.reject { |reg| reg.allocations.exists? }
  plan.first(needed).each_with_index do |(share, completed), i|
    registration = candidates[i]
    next unless registration
    award_scholarship.(registration, amount_cents: (cost * share).round, tasks_completed: completed)
  end
end

# --- A couple more on other paid events for cross-event variety ---
award_for_person.(mindful_art, samuel_s, amount_cents: 5_000, tasks_completed: true)
award_for_person.(trauma_training, angel_g, amount_cents: 6_000, tasks_completed: false)

[ facilitator_training, trauma_training, mindful_art ].compact.each do |event|
  dashboard = EventDashboard.new(event)
  puts "  #{event.title}: scholarships #{dashboard.scholarship_total_cents / 100.0} " \
       "(#{dashboard.scholarship_recipient_count} recipients), " \
       "allocated #{dashboard.allocated_scholarship_cents / 100.0}, " \
       "outstanding #{dashboard.outstanding_scholarship_cents / 100.0}"
end

puts "  Scholarship seeds complete!"
