
puts "Creating membership management scenarios…"

admin = User.find_by!(email: "umberto.user@example.com")
standard = Membership.annual_cost_cents
domain = "membershipdemo.seed.example.com"

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

membership_for = ->(person, start_date: Date.current - 3.months, cost_cents: nil, renewal_off: false) do
  person.memberships.create!(
    start_date: start_date,
    end_date: start_date + Membership::INVOICE_PERIOD - 1.day,
    cost_cents: cost_cents,
    renewal_off_at: renewal_off ? Time.current : nil
  )
end

minted_at = ->(start_date) {
  [ start_date.in_time_zone - Membership.renewal_window_days, Time.current ].min
}

pay = ->(invoice, cents, on:) do
  payment = CashPayment.create!(
    person: invoice.person,
    amount_cents: cents,
    amount_cents_remaining: cents,
    currency: Membership::CURRENCY
  )
  payment.update_columns(created_at: on, updated_at: on)
  allocation = Allocation.create!(source: payment, allocatable: invoice, amount: cents)
  allocation.update_columns(created_at: on)
end

discount = ->(invoice, cents, on:) do
  record = Discount.create!(amount_cents: cents)
  record.update_columns(created_at: on, updated_at: on)
  allocation = Allocation.create!(source: record, allocatable: invoice, amount: cents)
  allocation.update_columns(created_at: on)
end

stripe_pay = ->(invoice, cents, on:) do
  payment = ExternalProcessorPayment.new(
    person: invoice.person,
    amount_cents: cents,
    amount_cents_remaining: cents,
    currency: Membership::CURRENCY,
    external_origin: false,
    stripe_charge_id: "ch_mseed_#{invoice.id}",
    metadata: { "membership_invoice_id" => invoice.id }
  )
  payment.skip_pay_charge_validation = true
  payment.save!
  payment.update_columns(created_at: on, updated_at: on)
  allocation = Allocation.create!(source: payment, allocatable: invoice, amount: cents)
  allocation.update_columns(created_at: on)
end

attempt = ->(invoice, status:, message: nil, code: nil, on: Time.current) do
  invoice.charge_attempts.create!(
    attempt_number: (invoice.charge_attempts.maximum(:attempt_number) || 0) + 1,
    status: status,
    amount_cents: invoice.remaining_cost,
    attempted_at: on,
    error_code: code,
    error_message: message
  )
end

year = ->(membership, start_date, cost_cents: standard, paid: false, partial: nil) do
  invoice = membership.membership_invoices.create!(start_date: start_date, cost_cents: cost_cents)
  membership.update_columns(
    start_date: [ membership.start_date, invoice.start_date ].compact.min,
    end_date: [ membership.end_date, invoice.end_date ].compact.max
  )
  minted = minted_at.(start_date)
  invoice.update_columns(created_at: minted, updated_at: minted)

  paid_on = start_date.in_time_zone + 9.days
  if paid
    pay.(invoice, cost_cents, on: paid_on)
  elsif partial
    pay.(invoice, partial, on: paid_on)
  end
  invoice.update_columns(updated_at: paid_on) if paid || partial

  invoice
end

join = ->(person, start_date) do
  result = Membership::Create.call(person:, start_date:)
  raise result.errors.to_sentence unless result.success?

  membership = result.membership
  invoice = membership.membership_invoices.sole
  minted = minted_at.(start_date)
  membership.update_columns(created_at: start_date.in_time_zone, updated_at: start_date.in_time_zone)
  invoice.update_columns(created_at: minted, updated_at: minted)
  pay.(invoice, invoice.cost_cents, on: start_date.in_time_zone + 9.days)
  membership
end

autopay = ->(membership, card: true) do
  person = membership.person

  if card
    customer = Pay::Customer.find_or_create_by!(owner: person, processor: "stripe") do |record|
      record.processor_id = "cus_mseed_#{person.id}"
      record.default = true
    end
    Pay::Stripe::PaymentMethod.find_or_create_by!(customer: customer, processor_id: "pm_mseed_#{person.id}") do |method|
      method.payment_method_type = "card"
      method.brand = "Visa"
      method.last4 = "4242"
      method.exp_month = "12"
      method.exp_year = (Date.current.year + 2).to_s
      method.default = true
    end
  end

  membership.update!(autopay_on: true)
end

seed = ->(email:, first:, last:, label:, &block) do
  person = member.(email: email, first: first, last: last)
  next if person.memberships.exists?

  block.call(person)
  puts "  #{person.full_name}: #{label}"
end

seed.(email: "active.member", first: "Active", last: "Member", label: "Active — current year paid") do |person|
  membership = membership_for.(person)
  year.(membership, Date.current - 3.months, paid: true)
end

seed.(email: "ending.member", first: "Ending", last: "Member", label: "Ending — covered, renewal off") do |person|
  membership = membership_for.(person, renewal_off: true)
  year.(membership, Date.current - 3.months, paid: true)
end

seed.(email: "lapsed.owing", first: "Lapsed", last: "Owing", label: "Covered — renewal invoice unpaid") do |person|
  membership = membership_for.(person, start_date: Date.current - 2.years)
  paid = year.(membership, Date.current - 2.years, paid: true)
  year.(membership, paid.end_date + 1.day)
end

seed.(email: "ended.former", first: "Ended", last: "Former", label: "Ended — renewals stopped, coverage ran out") do |person|
  membership = membership_for.(person, start_date: Date.current - 2.years, renewal_off: true)
  year.(membership, Date.current - 2.years, paid: true)
end

seed.(email: "partial.payer", first: "Partial", last: "Payer", label: "Covered — partial payment on the renewal") do |person|
  membership = membership_for.(person, start_date: Date.current - 2.years)
  paid = year.(membership, Date.current - 2.years, paid: true)
  year.(membership, paid.end_date + 1.day, partial: 2_000)
end

seed.(email: "upcoming.renewal", first: "Upcoming", last: "Renewal", label: "Active — next year's invoice already issued") do |person|
  membership = membership_for.(person)
  current = year.(membership, Date.current - 3.months, paid: true)
  year.(membership, current.end_date + 1.day)
end

seed.(email: "free.year", first: "Free", last: "Year", label: "Active — $0 current year") do |person|
  membership = membership_for.(person)
  year.(membership, Date.current - 3.months, cost_cents: 0)
end

seed.(email: "grandfathered.member", first: "Grandfathered", last: "Member", label: "Active — locked at a lower cost") do |person|
  membership = membership_for.(person, cost_cents: 1_500)
  year.(membership, Date.current - 3.months, cost_cents: 1_500, paid: true)
end

seed.(email: "honorary.member", first: "Honorary", last: "Member", label: "Active — honorary, never billed") do |person|
  membership = membership_for.(person, cost_cents: 0)
  year.(membership, Date.current - 3.months, cost_cents: 0)
end

seed.(email: "rejoiner.member", first: "Rejoiner", last: "Member", label: "Active — lapsed, then rejoined") do |person|
  first_year = Date.current - 4.years
  lapsed = membership_for.(person, start_date: first_year, cost_cents: 1_500, renewal_off: true)
  lapsed.update_columns(created_at: first_year.in_time_zone, updated_at: first_year.in_time_zone)
  year.(lapsed, first_year, cost_cents: 1_500, paid: true)

  join.(person, Date.current - 1.month)
end

seed.(email: "duplicate.member", first: "Duplicate", last: "Member", label: "Anomaly — two unlocked memberships") do |person|
  first = membership_for.(person)
  year.(first, Date.current - 3.months, paid: true)
  second = membership_for.(person, start_date: Date.current - 5.years)
  year.(second, Date.current - 5.years, paid: true)
end

seed.(email: "autopay.active", first: "Autopay", last: "Active", label: "Active — autopay on, card on file") do |person|
  membership = membership_for.(person)
  year.(membership, Date.current - 3.months, paid: true)
  autopay.(membership)
end

seed.(email: "autopay.needs_card", first: "Autopay", last: "Needs card", label: "Active — autopay on, no card, payment due") do |person|
  membership = membership_for.(person)
  invoice = year.(membership, Date.current - 3.months)
  autopay.(membership, card: false)
  attempt.(invoice, status: "needs_card", code: "no_card", message: "No card is on file.", on: 1.day.ago)
end

seed.(email: "autopay.failed", first: "Autopay", last: "Failed", label: "Active — card declined, payment due") do |person|
  membership = membership_for.(person)
  invoice = year.(membership, Date.current - 3.months)
  autopay.(membership)
  attempt.(invoice, status: "failed", code: "card_declined",
    message: "Your card was declined. Try a different card or pay manually.", on: 1.day.ago)
end

seed.(email: "autopay.pending", first: "Autopay", last: "Pending", label: "Active — card charge in flight") do |person|
  membership = membership_for.(person)
  invoice = year.(membership, Date.current - 3.months)
  autopay.(membership)
  attempt.(invoice, status: "pending", code: "processing", message: "The charge is still processing.", on: 10.minutes.ago)
end

seed.(email: "partial.discount", first: "Partial", last: "Discount", label: "Active — $40 discount and $60 cash") do |person|
  membership = membership_for.(person)
  invoice = year.(membership, Date.current - 3.months)
  discount.(invoice, 4_000, on: Date.current - 3.months + 9.days)
  pay.(invoice, 6_000, on: Date.current - 3.months + 10.days)
end

seed.(email: "full.discount", first: "Full", last: "Discount", label: "Active — fully discounted year") do |person|
  membership = membership_for.(person)
  invoice = year.(membership, Date.current - 3.months)
  discount.(invoice, standard, on: Date.current - 3.months + 9.days)
end

seed.(email: "stripe.paid", first: "Stripe", last: "Paid", label: "Active — paid by card") do |person|
  membership = membership_for.(person)
  invoice = year.(membership, Date.current - 3.months)
  stripe_pay.(invoice, standard, on: Date.current - 3.months + 9.days)
end

seed.(email: "locked.arrears", first: "Locked", last: "Arrears", label: "Current membership plus a locked old one that still owes") do |person|
  old_start = Date.current - 3.years
  old = membership_for.(person, start_date: old_start, renewal_off: true)
  old_paid = year.(old, old_start, paid: true)
  year.(old, old_paid.end_date + 1.day, cost_cents: standard)

  join.(person, Date.current - 1.month)
end

puts "  #{Membership.count} memberships, #{MembershipInvoice.count} membership invoices"
