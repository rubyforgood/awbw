# `rake db:seed:dev`.

puts "Creating dues subscriptions for dev people…"

standard = Dues::ANNUAL_COST_CENTS

pool = Person.where.missing(:dues_subscriptions).order(:last_name, :first_name).to_a

if pool.size < 9
  puts "  Skipping: needs at least 9 people without dues (found #{pool.size}). Run db:seed:dev first."
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
    subscription.dues_registrations.create!(start_date: start_date, cost_cents: cost_cents)
  end

  scenarios = [
    # [ label, cost_cents, cancelled_at, years, payments ]
    [ "comped first year, as an invite leaves it", nil, nil,
      [ [ Date.current - 2.months, 0 ] ], [] ],

    [ "paid up for the current year", nil, nil,
      [ [ Date.current - 3.months, standard ] ], [ [ 0, standard ] ] ],

    [ "part paid inside the grace window — badge shows what is left", nil, nil,
      [ [ Date.current - 10.days, standard ] ], [ [ 0, 1_000 ] ] ],

    [ "unpaid but still inside the grace window", nil, nil,
      [ [ Date.current - 5.days, standard ] ], [] ],

    [ "overdue — unpaid past the grace window", nil, nil,
      [ [ Date.current - (Dues::GRACE_PERIOD_DAYS + 15).days, standard ] ], [] ],

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

    subscription = person.dues_subscriptions.create!(cost_cents: cost_cents, cancelled_at: cancelled_at)
    created = years.map { |start_date, cost_cents| year_for.(subscription, start_date, cost_cents) }
    payments.each { |year_index, cents| pay.(created[year_index], cents) }

    puts "  #{person.full_name}: #{label}"
  end

  # New subscription after old sub lapsed
  rejoiner = pool[9] || pool.first
  if rejoiner.dues_subscriptions.count < 2
    lapsed = rejoiner.dues_subscriptions.create!(cost_cents: 1_500, cancelled_at: Time.current - 2.years)
    pay.(year_for.(lapsed, Date.current - 4.years, 1_500), 1_500)

    rejoined = rejoiner.dues_subscriptions.create!
    pay.(year_for.(rejoined, Date.current - 1.month, standard), standard)

    puts "  #{rejoiner.full_name}: lapsed at the old cost, rejoined at the standard one"
  end
end

puts "  #{DuesSubscription.count} dues subscriptions, #{DuesRegistration.count} dues years"
