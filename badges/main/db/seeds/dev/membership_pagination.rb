# `rake db:seed:membership_pagination`. Not part of `rake db:seed:dev`.
# 30 memberships per directory state (Active / Ending / Lapsed / Ended) so every
# filter tab paginates. Years run back to back the way EnsureInvoice mints them, and
# each person's dates are offset so the directory doesn't read as one synthetic batch.
# Invoice variety (partial / upcoming / comped) lives in the dedicated
# `db/seeds/dev/membership.rb` scenarios.
# Also stages the price-change scenarios, one of which carries a real Stripe test
# subscription so the price sync can be exercised from the admin side.

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
    currency: "usd"
  )
  payment.update_columns(created_at: on, updated_at: on)
  allocation = Allocation.create!(source: payment, allocatable: invoice, amount: cents)
  allocation.update_columns(created_at: on)
end

year = ->(membership, start_date, cost_cents: standard, paid: false) do
  invoice = membership.membership_invoices.create!(start_date: start_date, cost_cents: cost_cents)
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

# Active — covered, renewing
build_group.("Active", "active") do |person, i|
  membership = person.memberships.create!
  year.(membership, Date.current - (3.months + i.days), paid: true)
end

# Ending — covered, renewal cancelled at some point in the last month
build_group.("Ending", "ending") do |person, i|
  membership = person.memberships.create!(autorenewal_cancelled_at: (Date.current - i.days).in_time_zone)
  year.(membership, Date.current - (3.months + i.days), paid: true)
end

# Lapsed — not covered, owes the renewal issued at the end of the paid year
build_group.("Lapsed", "lapsed") do |person, i|
  membership = person.memberships.create!
  paid = year.(membership, Date.current - (2.years + i.days), paid: true)
  year.(membership, paid.end_date + 1.day)
end

# Ended — not covered, nothing owed, because renewals were stopped during the year
build_group.("Ended", "ended") do |person, i|
  start = Date.current - (2.years + i.days)
  membership = person.memberships.create!(autorenewal_cancelled_at: start + 10.months)
  year.(membership, start, paid: true)
end

# ── price changes ────────────────────────────────────────────────────────────
# The Stripe price follows the next year's invoice, so raising the cost only reaches
# autopay once that year is re-issued: editing the cost sets what the next year mints
# at, and adding that invoice is what fires SyncMembershipSubscriptionPriceJob.
#
# Price Raised — next year still invoiced at the old price: the state the flow fixes.
# Price Live   — a real Stripe test subscription at the old price, so editing the cost
#                and adding the next year updates Stripe itself.
raised = standard + 5_000

add.("Raised", "Price", "price.raised", 0) do |person, _index|
  membership = person.memberships.create!(cost_cents: raised)
  current = year.(membership, Date.current - 3.months, paid: true)
  year.(membership, current.end_date + 1.day)
end

if Rails.env.development? && ENV["STRIPE_PRIVATE_KEY"].to_s.start_with?("sk_test_")
  begin
    add.("Live", "Price", "price.live", 0) do |person, _index|
      membership = person.memberships.create!
      invoice = year.(membership, Date.current - 3.months, paid: true)
      customer = person.set_payment_processor(:stripe)
      price = Stripe::Price.create(
        currency: "usd",
        unit_amount: invoice.cost_cents,
        recurring: { interval: "year" },
        product_data: { name: "AWBW annual membership (seed)" }
      )
      payment_method = Stripe::PaymentMethod.create({ type: "card", card: { token: "tok_visa" } })
      customer.add_payment_method(payment_method.id, default: true)
      customer.subscribe(
        name: "default",
        plan: price.id,
        metadata: { "membership_id" => membership.id },
        billing_cycle_anchor: Time.use_zone(Membership::TIME_ZONE) { (invoice.end_date + 1.day).beginning_of_day.to_i },
        proration_behavior: "none"
      )

      puts "  Price Live carries a real Stripe test subscription at " \
           "#{MoneyFormatter.dollars_from_cents(invoice.cost_cents)}. Open " \
           "#{Rails.application.routes.url_helpers.person_memberships_path(person)}, " \
           "edit the cost, then add the next year's invoice to sync it."
    end
  rescue Stripe::StripeError, Pay::Error => e
    puts "  Skipped Price Live: Stripe refused the subscription (#{e.message})."
  end
else
  puts "  Skipped Price Live: it needs development with Stripe test keys."
end

puts "  #{Membership.count} memberships, #{MembershipInvoice.count} membership invoices"
