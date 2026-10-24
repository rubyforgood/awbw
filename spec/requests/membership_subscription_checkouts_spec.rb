require "rails_helper"

RSpec.describe "Membership subscription checkouts", type: :request do
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

  def create_active_subscription
    customer = Pay::Customer.create!(owner: person, processor: "stripe",
      processor_id: "cus_test", default: true)
    Pay::Subscription.create!(customer: customer, name: "default",
      processor_id: "sub_test", processor_plan: "membership", status: "active", quantity: 1)
  end

  it "requires a signed-in user" do
    post memberships_subscription_checkouts_path

    expect(response).to redirect_to(new_user_session_path)
  end

  it "refuses a user with no person record" do
    sign_in create(:user)

    post memberships_subscription_checkouts_path

    expect(response).to redirect_to(root_path)
  end

  it "refuses a member with no membership rather than creating one" do
    sign_in user

    expect { post memberships_subscription_checkouts_path }.not_to change { Membership.count }

    expect(response).to redirect_to(root_path)
  end

  it "reuses an existing membership rather than making a second one" do
    create(:membership, person: person)
    sign_in user

    expect { post memberships_subscription_checkouts_path }.not_to change { Membership.count }
  end

  it "refuses a second subscription when one is already active" do
    create(:membership, person: person)
    create_active_subscription
    sign_in user

    post memberships_subscription_checkouts_path

    expect(response).to redirect_to(person_path(person))
    expect(checkout_args).to be_empty
  end

  it "charges the member's own locked rate, not the standard one" do
    create(:membership, person: person, cost_cents: 1_500)
    sign_in user

    post memberships_subscription_checkouts_path

    expect(checkout_args[:mode]).to eq("subscription")
    expect(checkout_args.dig(:line_items, 0, :price_data, :unit_amount)).to eq(1_500)
    expect(checkout_args.dig(:line_items, 0, :price_data, :recurring)).to eq({ interval: "year" })
  end

  it "charges immediately with no anchor when the current year is unpaid and not yet started" do
    create(:membership, person: person)
    sign_in user

    post memberships_subscription_checkouts_path

    expect(checkout_args[:subscription_data]).not_to have_key(:billing_cycle_anchor)
    expect(checkout_args[:subscription_data]).not_to have_key(:trial_end)
    expect(checkout_args[:line_items].size).to eq(1)
  end

  it "defers the first charge to the day after a year that is already paid" do
    membership = create(:membership, person: person)
    invoice = create(:membership_invoice, membership: membership, cost_cents: 2_500,
      start_date: Date.current, end_date: Date.current + 1.year - 1.day)
    create(:allocation, source: create(:payment, amount_cents: 2_500), allocatable: invoice, amount: 2_500)
    sign_in user

    post memberships_subscription_checkouts_path

    expect(checkout_args[:subscription_data][:billing_cycle_anchor])
      .to eq(Time.use_zone(Membership::TIME_ZONE) { (invoice.end_date + 1.day).beginning_of_day.to_i })
    expect(checkout_args[:subscription_data][:proration_behavior]).to eq("none")
    expect(checkout_args[:line_items].size).to eq(1)
  end

  it "carries the membership id so renewal charges can be traced back" do
    membership = create(:membership, person: person)
    sign_in user

    post memberships_subscription_checkouts_path

    expect(checkout_args[:metadata]).to eq({ membership_id: membership.id })
    expect(checkout_args[:subscription_data][:metadata]).to eq({ membership_id: membership.id })
    expect(checkout_args[:success_url]).to eq(person_url(person, membership_subscription_checkout: "success"))
  end

  it "refuses the subscription while the current balance is unpaid" do
    membership = create(:membership, person: person)
    create(:membership_invoice, membership: membership, cost_cents: 2_500,
      start_date: Date.current - 30.days, end_date: Date.current - 30.days + 1.year - 1.day)
    sign_in user

    post memberships_subscription_checkouts_path

    expect(response).to redirect_to(person_path(person))
  end

  it "refuses the subscription when the current balance's term starts today" do
    membership = create(:membership, person: person)
    create(:membership_invoice, membership: membership, cost_cents: 2_500,
      start_date: Date.current, end_date: Date.current + 1.year - 1.day)
    sign_in user

    post memberships_subscription_checkouts_path

    expect(response).to redirect_to(person_path(person))
  end

  it "allows the subscription when the only unpaid invoice is upcoming" do
    membership = create(:membership, person: person)
    paid = create(:membership_invoice, membership: membership, cost_cents: 2_500,
      start_date: Date.current - 3.months, end_date: Date.current - 3.months + 1.year - 1.day)
    create(:allocation, source: create(:payment, amount_cents: paid.cost_cents),
      allocatable: paid, amount: paid.cost_cents)
    create(:membership_invoice, membership: membership, cost_cents: 2_500,
      start_date: paid.end_date + 1.day, end_date: paid.end_date + 1.year)
    sign_in user

    post memberships_subscription_checkouts_path

    expect(response).to redirect_to("https://checkout.stripe.com/membership")
  end

  it "is refused while membership is disabled" do
    allow(Membership).to receive(:enabled?).and_return(false)
    sign_in user

    post memberships_subscription_checkouts_path

    expect(response).to redirect_to(root_path)
  end
end
