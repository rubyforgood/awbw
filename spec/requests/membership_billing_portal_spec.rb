require "rails_helper"

RSpec.describe "Membership billing portal", type: :request do
  let(:user) { create(:user, :with_person) }
  let(:person) { user.person }
  let(:fake_session) { double(url: "https://billing.stripe.com/membership") }
  let(:portal_args) { {} }
  let(:fake_processor) do
    instance_double("Pay::Stripe::Customer").tap do |processor|
      allow(processor).to receive(:billing_portal) do |**args|
        portal_args.merge!(args)
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
    post membership_billing_portals_path

    expect(response).to redirect_to(new_user_session_path)
  end

  it "refuses a user with no person record" do
    sign_in create(:user)

    post membership_billing_portals_path

    expect(response).to redirect_to(root_path)
  end

  it "refuses someone with no membership record" do
    sign_in user

    post membership_billing_portals_path

    expect(response).to redirect_to(root_path)
  end

  it "refuses someone with no active Stripe subscription" do
    create(:membership, person: person)
    sign_in user

    post membership_billing_portals_path

    expect(response).to redirect_to(person_path(person))
  end

  it "sends someone with an active subscription to the billing portal" do
    create(:membership, person: person)
    create_active_subscription
    sign_in user

    post membership_billing_portals_path

    expect(response).to redirect_to("https://billing.stripe.com/membership")
    expect(portal_args[:return_url]).to eq(person_url(person))
  end

  it "reports an alert when Stripe is unreachable" do
    create(:membership, person: person)
    create_active_subscription
    allow(fake_processor).to receive(:billing_portal).and_raise(Stripe::StripeError.new("down"))
    sign_in user

    post membership_billing_portals_path

    expect(response).to redirect_to(person_path(person))
  end

  it "is refused while membership is disabled" do
    allow(Membership).to receive(:enabled?).and_return(false)
    sign_in user

    post membership_billing_portals_path

    expect(response).to redirect_to(root_path)
  end
end
