# `rake db:seed:membership_pagination`. not part of `rake db:seed:dev`
puts "Creating membership pagination volume…"

first_names = %w[
  Ada Ben Cleo Dana Ellery Finn Gita Hana Idris Jules Keir Lena Micah Nina Ona
  Priya Quincy Rosa Sana Theo Uma Vale Wes Xena Yara Zoe Amir Bree Cato Del
].freeze
last_name_for = {
  current: "OnTime",
  due: "Due",
  overdue: "Overdue"
}
standard = Membership::ANNUAL_COST_CENTS

pay_invoice = ->(invoice) do
  payment = CashPayment.create!(
    person: invoice.person,
    amount_cents: invoice.cost_cents,
    amount_cents_remaining: invoice.cost_cents,
    currency: "usd"
  )
  Allocation.create!(source: payment, allocatable: invoice, amount: invoice.cost_cents)
end

add_membership = ->(first_name, last_name, marker, start_date, &build) do
  person = Person.find_or_create_by!(email: "#{marker}@paginationdemo.membership.seed.example.com") do |p|
    p.first_name = first_name
    p.last_name = last_name
  end
  return if person.memberships.autorenewal_not_cancelled.exists?

  membership = person.memberships.create!
  build.call(membership) if build
  puts "  #{person.full_name}: #{last_name}"
  membership
end

# 30 "paid up, renewal pre-issued" memberships → one row on current + one on upcoming.
first_names.each_with_index do |first_name, i|
  add_membership.call(first_name, last_name_for[:current], "current#{'%02d' % i}", Date.current - 3.months) do |membership|
    year = membership.membership_invoices.create!(start_date: Date.current - 3.months, cost_cents: standard)
    pay_invoice.call(year)
    membership.membership_invoices.create!(start_date: year.end_date + 1.day, cost_cents: standard)
  end
end

# 30 memberships with one unpaid invoice whose term has started.
first_names.each_with_index do |first_name, i|
  add_membership.call(first_name, last_name_for[:due], "due#{'%02d' % i}", Date.current - 5.days) do |membership|
    membership.membership_invoices.create!(start_date: Date.current - 5.days, cost_cents: standard)
  end
end

# 30 memberships with one unpaid invoice past start date.
first_names.each_with_index do |first_name, i|
  add_membership.call(first_name, last_name_for[:overdue], "overdue#{'%02d' % i}", Date.current - 45.days) do |membership|
    membership.membership_invoices.create!(
      start_date: Date.current - 45.days,
      cost_cents: standard
    )
  end
end

puts "  #{Membership.count} memberships, #{MembershipInvoice.count} membership invoices"
