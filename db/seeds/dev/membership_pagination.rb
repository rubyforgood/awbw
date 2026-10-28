
puts "Creating membership pagination volume…"

first_names = %w[
  Ada Ben Cleo Dana Ellery Finn Gita Hana Idris Jules Keir Lena Micah Nina Ona
  Priya Quincy Rosa Sana Theo Uma Vale Wes Xena Yara Zoe Amir Bree Cato Del
].freeze

standard = Membership.annual_cost_cents

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

membership_for = ->(person, start_date, cost_cents: nil, renewal_off: false) do
  person.memberships.create!(
    start_date: start_date,
    end_date: start_date + Membership::INVOICE_PERIOD - 1.day,
    cost_cents: cost_cents,
    autorenewal_cancelled_at: renewal_off ? Time.current : nil
  )
end

year = ->(membership, start_date, cost_cents: standard, paid: false) do
  invoice = membership.membership_invoices.create!(start_date: start_date, cost_cents: cost_cents)
  membership.update_columns(
    start_date: [ membership.start_date, invoice.start_date ].compact.min,
    end_date: [ membership.end_date, invoice.end_date ].compact.max
  )
  minted = minted_at.(start_date)
  invoice.update_columns(created_at: minted, updated_at: minted)

  if paid
    paid_on = start_date.in_time_zone + 9.days
    pay.(invoice, cost_cents, on: paid_on)
    invoice.update_columns(updated_at: paid_on)
  end

  invoice
end

add = ->(first_name, last_name, marker, index, &build) do
  person = Person.find_or_create_by!(email: "#{marker}@paginationdemo.membership.seed.example.com") do |p|
    p.first_name = first_name
    p.last_name = last_name
  end
  next if person.memberships.exists?

  build.call(person, index)
end

build_group = ->(last_name, prefix, &build) do
  first_names.each_with_index do |first_name, i|
    add.(first_name, last_name, "#{prefix}#{'%02d' % i}", i, &build)
  end
  puts "  #{first_names.size} #{last_name.downcase} memberships"
end

build_group.("Active", "active") do |person, i|
  membership = membership_for.(person, Date.current - (3.months + i.days))
  year.(membership, Date.current - (3.months + i.days), paid: true)
end

build_group.("Ending", "ending") do |person, i|
  membership = membership_for.(person, Date.current - (3.months + i.days), renewal_off: true)
  year.(membership, Date.current - (3.months + i.days), paid: true)
end

build_group.("Owing", "owing") do |person, i|
  start = Date.current - (2.years + i.days)
  membership = membership_for.(person, start)
  paid = year.(membership, start, paid: true)
  year.(membership, paid.end_date + 1.day)
end

build_group.("Upcoming", "upcoming") do |person, i|
  start = Date.current + (1.month + i.days)
  membership = membership_for.(person, start)
  year.(membership, start)
end

build_group.("Ended", "ended") do |person, i|
  start = Date.current - (2.years + i.days)
  membership = membership_for.(person, start, renewal_off: true)
  year.(membership, start, paid: true)
end

build_group.("Ended owing", "ended_owing") do |person, i|
  start = Date.current - (3.years + i.days)
  membership = membership_for.(person, start, renewal_off: true)
  paid = year.(membership, start, paid: true)
  year.(membership, paid.end_date + 1.day)
end

raised = standard + 5_000

add.("Raised", "Price", "price.raised", 0) do |person, _index|
  membership = membership_for.(person, Date.current - 3.months, cost_cents: raised)
  current = year.(membership, Date.current - 3.months, paid: true)
  year.(membership, current.end_date + 1.day, cost_cents: raised)
end

puts "  #{Membership.count} memberships, #{MembershipInvoice.count} membership invoices"
