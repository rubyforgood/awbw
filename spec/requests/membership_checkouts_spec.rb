require "rails_helper"

RSpec.describe "Membership checkouts", type: :request do
  around { |example| travel_to(Time.current.midday) { example.run } }

  let(:user) { create(:user, :with_person) }
  let(:person) { user.person }
  let(:fake_session) { double(url: "https://checkout.stripe.com/membership") }
  let(:checkout_args) { {} }
  let(:fake_processor) do
    instance_double("Pay::Stripe::Customer").tap do |processor|
      allow(processor).to receive(:checkout) do |**args|
        checkout_args.merge!(args)
        fake_session
      end
    end
  end

  before do
    allow_any_instance_of(Person).to receive(:set_payment_processor)
    allow_any_instance_of(Person).to receive(:payment_processor).and_return(fake_processor)
  end

  it "requires a signed-in user" do
    post membership_checkouts_path

    expect(response).to redirect_to(new_user_session_path)
  end

  it "refuses a user with no person record" do
    sign_in create(:user)

    post membership_checkouts_path

    expect(response).to redirect_to(root_path)
  end

  it "sends a member with no subscription to Stripe, creating the subscription and its year" do
    sign_in user

    expect { post membership_checkouts_path }
      .to change { person.memberships.count }.by(1)
      .and change { MembershipInvoice.count }.by(1)

    expect(response).to redirect_to("https://checkout.stripe.com/membership")
  end

  it "reuses an existing uncancelled subscription rather than making a second one" do
    subscription = create(:membership, person: person)
    create(:membership_invoice, membership: subscription,
      start_date: Date.current, end_date: Date.current + 1.year - 1.day)
    sign_in user

    expect { post membership_checkouts_path }.not_to change { Membership.count }
  end

  it "charges the member's own locked rate, not the standard one" do
    create(:membership, person: person, cost_cents: 1_500)
    sign_in user

    post membership_checkouts_path

    expect(checkout_args[:mode]).to eq("subscription")
    expect(checkout_args.dig(:line_items, 0, :price_data, :unit_amount)).to eq(1_500)
    expect(checkout_args.dig(:line_items, 0, :price_data, :recurring)).to eq({ interval: "year" })
  end

  it "charges immediately when the current year is unpaid" do
    sign_in user

    post membership_checkouts_path

    expect(checkout_args[:subscription_data]).not_to have_key(:trial_end)
  end

  it "defers the first charge to the day after a year that is already paid" do
    subscription = create(:membership, person: person)
    invoice = create(:membership_invoice, membership: subscription, cost_cents: 2_500,
      start_date: Date.current, end_date: Date.current + 1.year - 1.day)
    create(:allocation, source: create(:payment, amount_cents: 2_500), allocatable: invoice, amount: 2_500)
    sign_in user

    post membership_checkouts_path

    expect(checkout_args[:subscription_data][:trial_end])
      .to eq(Time.use_zone(Membership::TIME_ZONE) { (invoice.end_date + 1.day).beginning_of_day.to_i })
  end

  it "carries the subscription id so renewal charges can be traced back" do
    sign_in user

    post membership_checkouts_path

    subscription = person.memberships.sole
    expect(checkout_args[:metadata]).to eq({ membership_id: subscription.id })
    expect(checkout_args[:subscription_data][:metadata]).to eq({ membership_id: subscription.id })
  end

  it "is refused while membership is disabled" do
    allow(Membership).to receive(:enabled?).and_return(false)
    sign_in user

    post membership_checkouts_path

    expect(response).to redirect_to(root_path)
  end
end
