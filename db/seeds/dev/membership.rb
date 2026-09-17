# `rake db:seed:dev`.

puts "Creating memberships for dev people…"

standard = Membership::ANNUAL_COST_CENTS

# Checkout-flow scenarios for the named seed users — sign in and press
# "Set up annual membership" to see each billed shape:
#   amy   → overdue: current year already started, unpaid (one-time cover)
#   aisha → on time: current year starts today, unpaid (charged immediately)
# Umberto is deliberately absent: affiliation_history seeds his first membership
# and builds a multi-year history on it, so he can't be a checkout demo too.
# The "paid up — renewal defers to the anniversary" shape comes from the pool
# block's "paid up for the current year" person below.
# Skipped once the person already has an uncancelled membership, so reseeding
# doesn't clobber state you've since changed. Consumes these users before the
# pool block below, so their invoices stay the canonical checkout demos.
{
  "amy.user@example.com" => { label: "overdue — one-time cover + anchored renewal", start: Date.current - 10.days, pay: false },
  "aisha.user@example.com" => { label: "on time — charged immediately, no anchor", start: Date.current, pay: false }
}.each do |email, scenario|
  user = User.find_by(email: email)
  person = user&.person
  next unless person
  next if person.memberships.not_cancelled.exists?

  membership = person.memberships.create!
  invoice = MembershipInvoice.create!(
    membership: membership,
    start_date: scenario[:start],
    cost_cents: membership.cost_cents || standard
  )
  if scenario[:pay]
    payment = CashPayment.create!(
      person: person,
      amount_cents: invoice.cost_cents,
      amount_cents_remaining: invoice.cost_cents,
      currency: "usd"
    )
    Allocation.create!(source: payment, allocatable: invoice, amount: invoice.cost_cents)
  end

  puts "  #{person.full_name}: #{scenario[:label]}"
end

pool = Person.where.missing(:memberships).order(:last_name, :first_name).to_a

if pool.size < 9
  puts "  Skipping: needs at least 9 people without a membership (found #{pool.size}). Run db:seed:dev first."
else
  pay = ->(year, cents) do
    payment = CashPayment.create!(
      person: year.person,
      amount_cents: cents,
      amount_cents_remaining: cents,
      currency: "usd"
    )
    Allocation.create!(source: payment, allocatable: year, amount: cents)
  end

  year_for = ->(subscription, start_date, cost_cents) do
    subscription.membership_invoices.create!(start_date: start_date, cost_cents: cost_cents)
  end

  scenarios = [
    # [ label, cost_cents, cancelled_at, years, payments ]
    [ "comped first year, as an invite leaves it", nil, nil,
      [ [ Date.current - 2.months, 0 ] ], [] ],

    [ "paid up for the current year", nil, nil,
      [ [ Date.current - 3.months, standard ] ], [ [ 0, standard ] ] ],

    [ "part paid — badge shows Overdue", nil, nil,
      [ [ Date.current - 10.days, standard ] ], [ [ 0, 1_000 ] ] ],

    [ "unpaid — badge shows Overdue", nil, nil,
      [ [ Date.current - 5.days, standard ] ], [] ],

    [ "overdue — unpaid past start date", nil, nil,
      [ [ Date.current - 45.days, standard ] ], [] ],

    [ "renewal already created for next year", nil, nil,
      [ [ Date.current - 11.months, standard ], [ Date.current + 1.month, standard ] ],
      [ [ 0, standard ] ] ],

    [ "grandfathered at a lower cost", 1_500, nil,
      [ [ Date.current - 2.years, 1_500 ], [ Date.current - 1.year, 1_500 ], [ Date.current, 1_500 ] ],
      [ [ 0, 1_500 ], [ 1, 1_500 ] ] ],

    [ "honorary - never billed", 0, nil,
      [ [ Date.current - 1.year, 0 ], [ Date.current, 0 ] ], [] ],

    [ "cancelled, coverage runs to the end of the year", nil, Time.current - 1.week,
      [ [ Date.current - 4.months, standard ] ], [ [ 0, standard ] ] ]
  ]

  scenarios.each_with_index do |(label, cost_cents, cancelled_at, years, payments), index|
    person = pool[index]

    subscription = person.memberships.create!(cost_cents: cost_cents, cancelled_at: cancelled_at)
    created = years.map { |start_date, cost_cents| year_for.(subscription, start_date, cost_cents) }
    payments.each { |year_index, cents| pay.(created[year_index], cents) }

    puts "  #{person.full_name}: #{label}"
  end

  # New subscription after old sub lapsed
  rejoiner = pool[9] || pool.first
  if rejoiner.memberships.count < 2
    lapsed = rejoiner.memberships.create!(cost_cents: 1_500, cancelled_at: Time.current - 2.years)
    pay.(year_for.(lapsed, Date.current - 4.years, 1_500), 1_500)

    rejoined = rejoiner.memberships.create!
    pay.(year_for.(rejoined, Date.current - 1.month, standard), standard)

    puts "  #{rejoiner.full_name}: lapsed at the old cost, rejoined at the standard one"
  end
end

puts "  #{Membership.count} memberships, #{MembershipInvoice.count} membership invoices"
