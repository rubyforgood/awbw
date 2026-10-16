# `rake db:seed:membership`, or as part of `rake db:seed:dev`.
#
# One dedicated person per membership and invoice scenario, each with a login so the
# admin directory's lock toggle is exercisable on the non-payment / expired cases.
# Idempotent: a person who already holds a membership is skipped.

puts "Creating membership management scenarios…"

admin = User.find_by!(email: "umberto.user@example.com")
standard = Membership::ANNUAL_COST_CENTS
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

pay = ->(invoice, cents) do
  payment = CashPayment.create!(
    person: invoice.person,
    amount_cents: cents,
    amount_cents_remaining: cents,
    currency: "usd"
  )
  Allocation.create!(source: payment, allocatable: invoice, amount: cents)
end

year = ->(membership, start_date, cost_cents: standard, paid: false, partial: nil) do
  invoice = membership.membership_invoices.create!(start_date: start_date, cost_cents: cost_cents)
  pay.(invoice, cost_cents) if paid
  pay.(invoice, partial) if partial
  invoice
end

autopay = ->(person, membership, ends_at: nil) do
  customer = Pay::Customer.create!(
    owner: person,
    processor: "stripe",
    processor_id: "cus_mseed_#{membership.id}",
    default: true
  )
  Pay::Stripe::Subscription.create!(
    customer: customer,
    name: "default",
    processor_id: "sub_mseed_#{membership.id}",
    processor_plan: "membership",
    status: "active",
    quantity: 1,
    ends_at: ends_at,
    metadata: { "membership_id" => membership.id }
  )
end

seed = ->(email:, first:, last:, label:, &block) do
  person = member.(email: email, first: first, last: last)
  next if person.memberships.exists?

  block.call(person)
  puts "  #{person.full_name}: #{label}"
end

seed.(email: "active.member", first: "Active", last: "Member", label: "Active — current year paid") do |person|
  membership = person.memberships.create!
  year.(membership, Date.current - 3.months, paid: true)
end

seed.(email: "ending.member", first: "Ending", last: "Member", label: "Ending — covered, renewal cancelled") do |person|
  membership = person.memberships.create!(autorenewal_cancelled_at: Time.current)
  year.(membership, Date.current - 3.months, paid: true)
end

seed.(email: "lapsed.owing", first: "Lapsed", last: "Owing", label: "Lapsed — non-payment, owes the current year") do |person|
  membership = person.memberships.create!
  year.(membership, Date.current - 2.years, paid: true)
  year.(membership, Date.current - 8.months)
end

seed.(email: "ended.former", first: "Ended", last: "Former", label: "Ended — expired, nothing owed") do |person|
  membership = person.memberships.create!
  year.(membership, Date.current - 2.years, paid: true)
end

seed.(email: "partial.payer", first: "Partial", last: "Payer", label: "Lapsed — partial payment on the current year") do |person|
  membership = person.memberships.create!
  year.(membership, Date.current - 2.years, paid: true)
  year.(membership, Date.current - 8.months, partial: 2_000)
end

seed.(email: "upcoming.renewal", first: "Upcoming", last: "Renewal", label: "Active — next year's invoice already issued") do |person|
  membership = person.memberships.create!
  current = year.(membership, Date.current - 3.months, paid: true)
  year.(membership, current.end_date + 1.day)
end

seed.(email: "comped.year", first: "Comped", last: "Year", label: "Active — current year comped") do |person|
  membership = person.memberships.create!
  year.(membership, Date.current - 3.months, cost_cents: 0)
end

seed.(email: "no.invoice", first: "No", last: "Invoice", label: "Ended — membership with no invoices") do |person|
  person.memberships.create!
end

seed.(email: "grandfathered.member", first: "Grandfathered", last: "Member", label: "Active — locked at a lower cost") do |person|
  membership = person.memberships.create!(cost_cents: 1_500)
  year.(membership, Date.current - 3.months, cost_cents: 1_500, paid: true)
end

seed.(email: "honorary.member", first: "Honorary", last: "Member", label: "Active — honorary, never billed") do |person|
  membership = person.memberships.create!(cost_cents: 0)
  year.(membership, Date.current - 3.months, cost_cents: 0)
end

seed.(email: "rejoiner.member", first: "Rejoiner", last: "Member", label: "Active — lapsed, then rejoined") do |person|
  lapsed = person.memberships.create!(cost_cents: 1_500, autorenewal_cancelled_at: Time.current - 2.years)
  year.(lapsed, Date.current - 4.years, cost_cents: 1_500, paid: true)
  rejoined = person.memberships.create!
  year.(rejoined, Date.current - 1.month, paid: true)
end

seed.(email: "duplicate.member", first: "Duplicate", last: "Member", label: "Anomaly — two uncancelled memberships") do |person|
  first = person.memberships.create!
  year.(first, Date.current - 3.months, paid: true)
  second = person.memberships.create!(autorenewal_cancelled_at: Time.current)
  year.(second, Date.current - 5.years, paid: true)
  second.update_columns(autorenewal_cancelled_at: nil)
end

seed.(email: "autopay.active", first: "Autopay", last: "Active", label: "Active — Stripe autopay on") do |person|
  membership = person.memberships.create!
  year.(membership, Date.current - 3.months, paid: true)
  autopay.(person, membership)
end

seed.(email: "autopay.cancelling", first: "Autopay", last: "Cancelling", label: "Active — autopay set to stop at the year's end") do |person|
  membership = person.memberships.create!
  year.(membership, Date.current - 3.months, paid: true)
  autopay.(person, membership, ends_at: Date.current + 9.months)
end

puts "  #{Membership.count} memberships, #{MembershipInvoice.count} membership invoices"
