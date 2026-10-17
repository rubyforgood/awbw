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
end
