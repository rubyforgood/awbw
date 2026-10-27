require "rails_helper"

RSpec.describe "Person profile membership card", type: :request do
  around { |example| travel_to(Time.current.midday) { example.run } }

  let(:user) { create(:user, :with_person) }
  let(:person) { user.person }

  def subscribe_to(membership)
    customer = Pay::Customer.create!(owner: person, processor: "stripe", processor_id: "cus_test", default: true)
    Pay::Stripe::Subscription.create!(customer: customer, name: "default", processor_id: "sub_test",
      processor_plan: "membership", status: "active", quantity: 1,
      metadata: { "membership_id" => membership.id })
  end

  it "shows the membership the live subscription belongs to, not a newer cancelled one" do
    live = create(:membership, person: person)
    subscribe_to(live)
    create(:membership, :autorenewal_cancelled, person: person,
      start_date: Date.current + 2.years, end_date: Date.current + 3.years)

    sign_in user
    get person_path(person)

    expect(response.body).to include(live.end_date.strftime("%b %-d, %Y"))
  end

  it "offers the setup action to the owner" do
    create(:membership, person: person)
    sign_in user

    get person_path(person)

    expect(response.body).to include("Set up automatic renewal")
    expect(response.body).to include(memberships_subscription_checkouts_path)
  end

  it "offers the manage-autopay action to the owner when subscribed" do
    membership = create(:membership, person: person)
    subscribe_to(membership)

    sign_in user
    get person_path(person)

    expect(response.body).to include("Manage autopay")
    expect(response.body).to include(memberships_billing_portals_path)
  end

  it "hides the action buttons from an admin viewing someone else's profile" do
    create(:membership, person: person)
    sign_in create(:user, :admin)

    get person_path(person)

    expect(response.body).to include("Annual membership")
    expect(response.body).not_to include("Set up automatic renewal")
    expect(response.body).not_to include(memberships_subscription_checkouts_path)
    expect(response.body).not_to include(memberships_billing_portals_path)
  end

  it "offers a Pay action on an outstanding invoice, carrying its id" do
    membership = create(:membership, person: person)
    create(:membership_invoice, membership: membership, cost_cents: 2_500,
      start_date: Date.current - 30.days, end_date: Date.current - 30.days + 1.year - 1.day)
    sign_in user

    get person_path(person)

    expect(response.body).to include("Pay")
    expect(response.body).to include(memberships_invoice_checkouts_path)
    expect(response.body).to include('name="invoice_id"')
  end

  it "hides the Pay action from an admin viewing someone else's outstanding invoice" do
    membership = create(:membership, person: person)
    create(:membership_invoice, membership: membership, cost_cents: 2_500,
      start_date: Date.current - 30.days, end_date: Date.current - 30.days + 1.year - 1.day)
    sign_in create(:user, :admin)

    get person_path(person)

    expect(response.body).not_to include(memberships_invoice_checkouts_path)
  end

  it "offers Pay for an invoice that starts today" do
    membership = create(:membership, person: person)
    create(:membership_invoice, membership: membership, cost_cents: 2_500,
      start_date: Date.current, end_date: Date.current + 1.year - 1.day)
    sign_in user

    get person_path(person)

    expect(response.body).to include('name="invoice_id"')
  end

  it "shows an upcoming invoice without a Pay button" do
    membership = create(:membership, person: person)
    create(:membership_invoice, membership: membership, cost_cents: 2_500,
      start_date: Date.current + 1.month, end_date: Date.current + 1.month + 1.year - 1.day)
    sign_in user

    get person_path(person)

    expect(response.body).to include("Upcoming")
    expect(response.body).not_to include('name="invoice_id"')
  end

  it "does not show a fully paid invoice" do
    membership = create(:membership, person: person)
    paid = create(:membership_invoice, membership: membership, cost_cents: 2_500,
      start_date: Date.current - 30.days, end_date: Date.current - 30.days + 1.year - 1.day)
    create(:allocation, source: create(:payment, amount_cents: paid.cost_cents),
      allocatable: paid, amount: paid.cost_cents)
    sign_in user

    get person_path(person)

    expect(response.body).not_to include('name="invoice_id"')
  end

  it "reads the upcoming start date instead of calling the membership ended" do
    membership = create(:membership, person: person,
      start_date: Date.current + 1.month, end_date: Date.current + 13.months)
    sign_in user

    get person_path(person)

    expect(response.body).to include("Membership starts:")
    expect(response.body).to include(membership.start_date.strftime("%b %-d, %Y"))
    expect(response.body).not_to include("Membership ended:")
  end

  it "defers automatic renewal setup until a directly paid year has begun" do
    membership = create(:membership, person: person, start_date: nil, end_date: nil)
    invoice = create(:membership_invoice, membership: membership, cost_cents: 2_500,
      start_date: Date.current + 1.day, end_date: Date.current + 1.year)
    create(:allocation, source: create(:payment, amount_cents: 2_500),
      allocatable: invoice, amount: 2_500)
    sign_in user

    get person_path(person)

    expect(response.body).to include("closer to your renewal date")
    expect(response.body).to include("paid directly")
    expect(response.body).not_to include("Set up automatic renewal")
  end
end
