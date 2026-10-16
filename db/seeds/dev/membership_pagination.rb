# `rake db:seed:membership_pagination`. Not part of `rake db:seed:dev`.
# 30 memberships per directory state (Active / Ending / Lapsed / Ended) so every
# filter tab paginates. Invoice variety (partial / upcoming / comped) lives in the
# dedicated `db/seeds/dev/membership.rb` scenarios.

puts "Creating membership pagination volume…"

first_names = %w[
  Ada Ben Cleo Dana Ellery Finn Gita Hana Idris Jules Keir Lena Micah Nina Ona
  Priya Quincy Rosa Sana Theo Uma Vale Wes Xena Yara Zoe Amir Bree Cato Del
].freeze

standard = Membership::ANNUAL_COST_CENTS

pay = ->(invoice, cents) do
  payment = CashPayment.create!(
    person: invoice.person,
    amount_cents: cents,
    amount_cents_remaining: cents,
    currency: "usd"
  )
  Allocation.create!(source: payment, allocatable: invoice, amount: cents)
end

year = ->(membership, start_date, cost_cents: standard, paid: false) do
  invoice = membership.membership_invoices.create!(start_date: start_date, cost_cents: cost_cents)
  pay.(invoice, cost_cents) if paid
  invoice
end

add = ->(first_name, last_name, marker, &build) do
  person = Person.find_or_create_by!(email: "#{marker}@paginationdemo.membership.seed.example.com") do |p|
    p.first_name = first_name
    p.last_name = last_name
  end
  next if person.memberships.exists?

  build.call(person)
end

build_group = ->(last_name, prefix, &build) do
  first_names.each_with_index do |first_name, i|
    add.(first_name, last_name, "#{prefix}#{'%02d' % i}", &build)
  end
  puts "  #{first_names.size} #{last_name.downcase} memberships"
end

# Active — covered, renewing
build_group.("Active", "active") do |person|
  membership = person.memberships.create!
  year.(membership, Date.current - 3.months, paid: true)
end

# Ending — covered, renewal cancelled
build_group.("Ending", "ending") do |person|
  membership = person.memberships.create!(autorenewal_cancelled_at: Time.current)
  year.(membership, Date.current - 3.months, paid: true)
end

# Lapsed — not covered, owes the current year
build_group.("Lapsed", "lapsed") do |person|
  membership = person.memberships.create!
  year.(membership, Date.current - 2.years, paid: true)
  year.(membership, Date.current - 8.months)
end

# Ended — not covered, nothing owed
build_group.("Ended", "ended") do |person|
  membership = person.memberships.create!
  year.(membership, Date.current - 2.years, paid: true)
end

puts "  #{Membership.count} memberships, #{MembershipInvoice.count} membership invoices"
