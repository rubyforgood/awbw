puts "Creating membership reconciliation scenarios…"

admin = User.find_by!(email: "umberto.user@example.com")
standard = Membership.annual_cost_cents
domain = "reconciliationdemo.seed.example.com"

member = ->(email:, first:, last:) do
  user = User.find_or_create_by!(email: "#{email}@#{domain}") do |u|
    u.password = "password"
    u.super_user = false
    u.confirmed_at = Time.current
  end
  if user.person.nil?
    user.update!(person: Person.create!(
      first_name: first,
      last_name: last,
      email: user.email,
      created_by: admin,
      updated_by: admin,
      profile_is_searchable: true
    ))
  end
  user.person
end

membership_for = ->(person) do
  start_date = Date.current - 3.months
  person.memberships.create!(
    start_date:,
    end_date: start_date + Membership::INVOICE_PERIOD - 1.day
  )
end

invoice_for = ->(membership) do
  membership.membership_invoices.create!(
    start_date: membership.start_date,
    cost_cents: standard
  )
end

attempt = ->(invoice, status:, on: 1.hour.ago, **attrs) do
  invoice.charge_attempts.create!(
    attempt_number: (invoice.charge_attempts.maximum(:attempt_number) || 0) + 1,
    status:,
    amount_cents: invoice.remaining_cost,
    attempted_at: on,
    **attrs
  )
end

pay = ->(invoice, cents) do
  payment = CashPayment.create!(
    person: invoice.person,
    amount_cents: cents,
    amount_cents_remaining: cents,
    currency: Membership::CURRENCY
  )
  Allocation.create!(source: payment, allocatable: invoice, amount: cents)
end

customer_for = ->(person) do
  customer = Pay::Stripe::Customer.find_or_initialize_by(owner: person, processor: "stripe")
  customer.update!(processor_id: "cus_recon_#{person.id}", default: true)

  method = Pay::Stripe::PaymentMethod.find_or_initialize_by(
    customer:, processor_id: "pm_recon_#{person.id}"
  )
  method.update!(
    payment_method_type: "card",
    brand: "Visa",
    last4: "4242",
    exp_month: "12",
    exp_year: (Date.current.year + 2).to_s,
    default: true
  )

  customer
end

charge_for = ->(person, invoice) do
  customer = customer_for.(person)
  processor_id = "ch_recon_#{invoice.id}"

  Pay::Charge.find_or_create_by!(customer:, processor_id:) do |charge|
    charge.amount = standard
    charge.amount_refunded = 0
    charge.currency = Membership::CURRENCY
    charge.metadata = {}
    charge.object = {
      "id" => processor_id,
      "object" => "charge",
      "amount" => standard,
      "currency" => Membership::CURRENCY,
      "paid" => false,
      "metadata" => {},
      "refunds" => { "object" => "list", "data" => [], "has_more" => false }
    }
  end
end

seed = ->(email:, first:, last:, label:, &block) do
  person = member.(email:, first:, last:)
  next if person.memberships.exists?

  block.call(person)
  puts "  #{person.full_name}: #{label}"
end

seed.(email: "reconcile.pending", first: "Reconcile", last: "Pending",
  label: "Pending attempt with no PaymentIntent: Mark failed works locally") do |person|
  membership = membership_for.(person)
  invoice = invoice_for.(membership)
  attempt.(invoice, status: "pending", on: 1.hour.ago,
    error_code: "processing", error_message: "The charge is still processing.")
end

seed.(email: "reconcile.needs-action", first: "Reconcile", last: "Needs action",
  label: "Needs authentication: cancel/reconcile buttons") do |person|
  membership = membership_for.(person)
  invoice = invoice_for.(membership)
  attempt.(invoice, status: "needs_action", on: 1.hour.ago,
    payment_intent_id: "pi_recon_needs_action_#{person.id}",
    error_code: "authentication_required",
    error_message: "The card needs the member to complete the payment.")
end

seed.(email: "reconcile.unallocated", first: "Reconcile", last: "Unallocated",
  label: "Unallocated Stripe payment: Apply $X works locally") do |person|
  membership = membership_for.(person)
  invoice = invoice_for.(membership)
  charge = charge_for.(person, invoice)

  ExternalProcessorPayment.find_or_create_by!(stripe_charge_id: charge.processor_id) do |record|
    record.person = person
    record.amount_cents = standard
    record.amount_cents_remaining = standard
    record.currency = Membership::CURRENCY
    record.external_origin = false
    record.pay_charge = charge
    record.metadata = { "membership_invoice_id" => invoice.id }
  end

  attempt.(invoice, status: "unknown", on: 1.hour.ago, pay_charge: charge,
    error_code: "allocation_failed",
    error_message: "The charge succeeded but was not applied to this invoice.")
end

seed.(email: "reconcile.credit", first: "Reconcile", last: "Credit",
  label: "Paid invoice with a $25 portal credit: acknowledge hides it from Data health") do |person|
  membership = membership_for.(person)
  invoice = invoice_for.(membership)
  pay.(invoice, standard)

  credit = ExternalProcessorPayment.new(
    person:,
    amount_cents: 2_500,
    amount_cents_remaining: 2_500,
    currency: Membership::CURRENCY,
    external_origin: false,
    stripe_charge_id: "ch_recon_credit_#{person.id}",
    metadata: { "membership_invoice_id" => invoice.id }
  )
  credit.skip_pay_charge_validation = true
  credit.save!
end

seed.(email: "reconcile.stale-checkout", first: "Reconcile", last: "Stale checkout",
  label: "Stale checkout session: Check checkout session button") do |person|
  membership = membership_for.(person)
  invoice = invoice_for.(membership)
  invoice.update_columns(
    checkout_session_id: "cs_recon_stale_#{person.id}",
    payment_in_progress_at: 2.hours.ago
  )
end

puts "  #{Membership.count} memberships, #{MembershipChargeAttempt.unresolved.count} unresolved attempts"
puts "  Stripe lookups use fake ids; local Apply and Mark failed actions work offline."
