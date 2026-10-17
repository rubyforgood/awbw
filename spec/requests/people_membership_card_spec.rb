require "rails_helper"

RSpec.describe "Person profile membership card", type: :request do
  around { |example| travel_to(Time.current.midday) { example.run } }

  let(:user) { create(:user, :with_person) }
  let(:person) { user.person }

  def subscribe_to(membership)
    customer = Pay::Customer.create!(owner: person, processor: "stripe", processor_id: "cus_test", default: true)
    Pay::Subscription.create!(customer: customer, name: "default", processor_id: "sub_test",
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
    expect(response.body).to include(membership_subscription_checkouts_path)
  end

  it "hides the action buttons from an admin viewing someone else's profile" do
    create(:membership, person: person)
    sign_in create(:user, :admin)

    get person_path(person)

    expect(response.body).to include("Annual membership")
    expect(response.body).not_to include("Set up automatic renewal")
    expect(response.body).not_to include(membership_subscription_checkouts_path)
    expect(response.body).not_to include(membership_billing_portals_path)
  end

  it "offers a Pay action on an outstanding invoice, carrying its id" do
    membership = create(:membership, person: person)
    create(:membership_invoice, membership: membership, cost_cents: 2_500,
      start_date: Date.current - 30.days, end_date: Date.current - 30.days + 1.year - 1.day)
    sign_in user

    get person_path(person)

    expect(response.body).to include("Pay")
    expect(response.body).to include(membership_invoice_checkouts_path)
    expect(response.body).to include('name="invoice_id"')
  end
end
