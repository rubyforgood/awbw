# Bulk payment seeds (dev-only) — run on their own via `rake db:seed:bulk_payments`,
# or as part of `rake db:seed:dev`. Adds SEVERAL bulk payments to the flagship
# event (AWBW Facilitator Training, "event 1") so its bulk payments page exercises
# the full matrix of states. This file is the single source of seeded bulk payments.
#
# How money lands on a bulk payment — two real channels:
#   * Stripe webhook (credit card): a "Credit card (now)" checkout completes and
#     PayChargeExtensions#create_bulk_payment creates an ExternalProcessorPayment
#     (a Pay-gem-backed payment) linked to the submission. webhook_payment below
#     reproduces that record (it skips the Pay::Charge link, which no view reads).
#   * Cash / check: staff log the money directly as a plain CashPayment / CheckPayment
#     linked to the submission and record Allocations against the matching
#     registrations — NOT Pay-gem tables. recorded_payment below does this.
#   * Not yet paid: no Payment record at all (a card-later submission, an abandoned
#     card-now checkout, or a check that hasn't arrived). The card shows the
#     expected amount (count x cost) with a pending badge and no Allocate forms.
#
# Coverage:
#   * Several bulk payments on one event, different payers and methods.
#   * Attendees who are registered (match → Allocate / Form submission / Registration
#     allocations controls), in the db but NOT registered (No match), and not in the
#     db at all (No match).
#   * Payments unallocated, partially allocated, and fully allocated, including a
#     registered attendee already paid in full (no Allocate form despite the payment
#     having a remaining balance).
#
# Re-runnable: this seed's own submissions (identified by their payer emails), the
# payments tied to them, and the allocations sourced from those payments are torn
# down and rebuilt on every run. A stray demo event from an earlier version of this
# file is also cleaned up.

event = Event.find_by(title: "AWBW Facilitator Training")
unless event
  puts "Skipping bulk payment demo — AWBW Facilitator Training not seeded yet."
  return
end

bulk_form = event.bulk_payment_form
unless bulk_form
  puts "Skipping bulk payment demo — AWBW Facilitator Training has no bulk payment form."
  return
end

puts "Seeding bulk payment demo on '#{event.title}' (webhook, cash/check, and pending)…"

cost_cents = event.cost_cents.to_i
payer_domain = "bulkpaydemo.seed.example.com" # marks this seed's payers for teardown

# --- Clean up the stray demo event from an earlier version of this file ---------
old_event = Event.find_by(title: "Bulk Payment Demo Training")
if old_event
  old_form = Form.find_by(owner: old_event, role: "bulk_payment")
  if old_form
    old_subs = FormSubmission.where(form: old_form)
    old_pay_ids = Payment.where(form_submission_id: old_subs.select(:id)).pluck(:id)
    Allocation.where(source_type: "Payment", source_id: old_pay_ids).delete_all
    Payment.where(id: old_pay_ids).delete_all
    old_subs.destroy_all
    old_form.event_forms.destroy_all
    old_form.destroy
  end
  old_event.event_registrations.destroy_all
  old_event.destroy
end

# --- Teardown this seed's prior submissions on the event (by payer marker) -------
prior_payers = Person.where("email LIKE ?", "%@#{payer_domain}")
prior_subs = FormSubmission.where(person: prior_payers, form: bulk_form, role: "bulk_payment")
prior_pay_ids = Payment.where(form_submission_id: prior_subs.select(:id)).pluck(:id)
Allocation.where(source_type: "Payment", source_id: prior_pay_ids).delete_all
Payment.where(id: prior_pay_ids).delete_all
prior_subs.destroy_all

# --- Helpers --------------------------------------------------------------------
make_person = ->(first, last, email) do
  Person.find_or_create_by!(email: email) do |p|
    p.first_name = first
    p.last_name = last
  end
end

register = ->(person) do
  EventRegistration.find_or_create_by!(event: event, registrant: person) do |reg|
    reg.status = "registered"
  end
end

set_answer = ->(submission, identifier, value) do
  field = bulk_form.form_fields.find_by(field_identifier: identifier)
  return unless field
  submission.form_answers.create!(form_field: field, submitted_answer: value.to_s,
                                  question_name_when_answered: field.name)
end

# Build a bulk payment submission for a payer. attendees is an array of
# [first, last, email] tuples, serialized as JSON under "bulk_payment_attendees".
build_submission = ->(payer:, method:, attendees:) do
  # Record the event directly: the bulk payments page filters submissions by
  # event_id (see EventsController#bulk_payments), so an event-less submission
  # would never show up there.
  submission = FormSubmission.create!(person: payer, form: bulk_form, event: event, role: "bulk_payment")
  set_answer.(submission, "payer_first_name", payer.first_name)
  set_answer.(submission, "payer_last_name", payer.last_name)
  set_answer.(submission, "payer_email", payer.email)
  set_answer.(submission, "number_of_attendees", attendees.size)
  set_answer.(submission, "payment_method", method)
  attendee_json = attendees.map do |first, last, email|
    { "first_name" => first, "last_name" => last, "email" => email }
  end
  set_answer.(submission, "bulk_payment_attendees", attendee_json.to_json)
  submission
end

# Credit card paid via Stripe: the post-webhook ExternalProcessorPayment, mirroring
# PayChargeExtensions#create_bulk_payment (external_origin: false, payer is the
# submitter, attendees + count copied into metadata).
webhook_payment = ->(submission, amount_cents:, created_at:) do
  payment = ExternalProcessorPayment.new(
    person: submission.person,
    form_submission: submission,
    amount_cents: amount_cents,
    amount_cents_remaining: amount_cents,
    currency: "usd",
    external_origin: false,
    stripe_charge_id: "ch_seed_#{submission.id}",
    metadata: {
      "form_submission_id" => submission.id,
      "event_id" => event.id,
      "attendees" => submission.bulk_payment_attendees,
      "number_of_attendees" => submission.bulk_payment_attendee_count
    },
    created_at: created_at
  )
  payment.skip_pay_charge_validation = true
  payment.save!
  payment
end

# Cash or check the staff logged by hand: a plain (non-Pay-gem) CashPayment /
# CheckPayment linked to the submission, against which Allocations are recorded.
recorded_payment = ->(submission, kind:, amount_cents:, created_at:) do
  attrs = {
    person: submission.person,
    form_submission: submission,
    amount_cents: amount_cents,
    amount_cents_remaining: amount_cents,
    currency: "usd",
    created_at: created_at
  }
  if kind == :check
    CheckPayment.create!(**attrs, check_number: "CHK-BPD-#{submission.id}")
  else
    CashPayment.create!(**attrs)
  end
end

# Record an allocation logging part of a payment against a registration. Decrements
# the payment's remaining balance via the model's after_create callback.
allocate = ->(payment, person, amount_cents, created_at) do
  registration = EventRegistration.find_by(event: event, registrant: person)
  return unless payment && registration
  Allocation.create!(source: payment, allocatable: registration, amount: amount_cents, created_at: created_at)
end

# --- People (dedicated to this demo so allocation states stay controlled) --------
# Registered attendees — match on the card.
bea  = make_person.("Bea", "Checkpaid", "bea.checkpaid@bulkpay.seed.example.com")
cy   = make_person.("Cy", "Checkowing", "cy.checkowing@bulkpay.seed.example.com")
dot  = make_person.("Dot", "Cashfull", "dot.cashfull@bulkpay.seed.example.com")
eli  = make_person.("Eli", "Cashfull", "eli.cashfull@bulkpay.seed.example.com")
fay  = make_person.("Fay", "Cardpaid", "fay.cardpaid@bulkpay.seed.example.com")
gus  = make_person.("Gus", "Cardowing", "gus.cardowing@bulkpay.seed.example.com")
hal  = make_person.("Hal", "Pending", "hal.pending@bulkpay.seed.example.com")
liz  = make_person.("Liz", "Later", "liz.later@bulkpay.seed.example.com")
[ bea, cy, dot, eli, fay, gus, hal, liz ].each { |person| register.(person) }

# In the db but NOT registered for this event → No match.
ivy = make_person.("Ivy", "Notregistered", "ivy.notregistered@bulkpay.seed.example.com")

# Not in the db at all — only names on the submission → No match.
jake = [ "Jake", "External", "jake.external@external.example.com" ]
kara = [ "Kara", "External", "kara.external@external.example.com" ]

# Payers (the people who submitted/paid; their emails mark this seed's data).
shelter = make_person.("Northside Shelter", "Payments", "northside@#{payer_domain}")
agency  = make_person.("Eastside Agency", "Payments", "eastside@#{payer_domain}")
quentin = make_person.("Quentin", "Cardpayer", "quentin.cardpayer@#{payer_domain}")
rita    = make_person.("Rita", "Checklater", "rita.checklater@#{payer_domain}")
sam     = make_person.("Sam", "Paylater", "sam.paylater@#{payer_domain}")

listed = ->(person) { [ person.first_name, person.last_name, person.email ] }

# --- Scenario 1: CHECK logged by staff, partially allocated ---------------------
# $4,500 check covers 3 seats. Bea is allocated her full $1,500 (paid in full → no
# Allocate form); Cy is still owing and the payment has $3,000 left, so Cy shows an
# Allocate form. Ivy is in the db but not registered → No match.
s1 = build_submission.(payer: shelter, method: "Check",
  attendees: [ listed.(bea), listed.(cy), listed.(ivy) ])
p1 = recorded_payment.(s1, kind: :check, amount_cents: cost_cents * 3, created_at: 12.days.ago)
allocate.(p1, bea, cost_cents, 11.days.ago)

# --- Scenario 2: CASH logged by staff, fully allocated --------------------------
# $3,000 cash for 2 seats, both allocated their full cost → $0 remaining, both paid
# in full. Method is "Other" (cash isn't a payer-selectable option on the form).
s2 = build_submission.(payer: agency, method: "Other",
  attendees: [ listed.(dot), listed.(eli) ])
p2 = recorded_payment.(s2, kind: :cash, amount_cents: cost_cents * 2, created_at: 9.days.ago)
allocate.(p2, dot, cost_cents, 8.days.ago)
allocate.(p2, eli, cost_cents, 8.days.ago)

# --- Scenario 3: CREDIT CARD via Stripe webhook, unallocated --------------------
# $4,500 ExternalProcessorPayment, nothing allocated yet → Fay and Gus both show
# Allocate forms. Kara isn't in the db → No match.
s3 = build_submission.(payer: quentin, method: "Credit card (now)",
  attendees: [ listed.(fay), listed.(gus), kara ])
webhook_payment.(s3, amount_cents: cost_cents * 3, created_at: 5.days.ago)

# --- Scenario 4: CHECK not yet arrived (pending, no payment) --------------------
# Hal matches (registered) but with no payment there's no Allocate form — just the
# matched-person card plus the Form submission / Registration allocations buttons.
build_submission.(payer: rita, method: "Check", attendees: [ listed.(hal) ])

# --- Scenario 5: CARD (later) — pending by design, no payment yet ---------------
# Liz matches (registered); Jake isn't in the db → No match.
build_submission.(payer: sam, method: "Credit card (later)",
  attendees: [ listed.(liz), jake ])

submissions = FormSubmission.where(person: Person.where("email LIKE ?", "%@#{payer_domain}"),
                                   form: bulk_form, role: "bulk_payment")
paid = Payment.where(form_submission: submissions).group(:type).count
puts "  Added #{submissions.count} bulk payments to '#{event.title}' " \
     "(payments: #{paid.map { |t, c| "#{c} #{t}" }.join(', ')}; the rest pending)"
puts "  Bulk payment seeds complete!"
