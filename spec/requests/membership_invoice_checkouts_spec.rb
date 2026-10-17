require "rails_helper"

RSpec.describe "Membership invoice checkouts", type: :request do
  around { |example| travel_to(Time.current.midday) { example.run } }

  let(:user) { create(:user, :with_person) }
  let(:person) { user.person }
  let(:membership) { create(:membership, person: person) }
  let!(:invoice) do
    create(:membership_invoice, membership: membership, cost_cents: 2_500,
      start_date: Date.current - 30.days, end_date: Date.current - 30.days + 1.year - 1.day)
  end
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
    post membership_invoice_checkouts_path, params: { invoice_id: invoice.id }

    expect(response).to redirect_to(new_user_session_path)
  end

  it "charges an already-started, unpaid year one-time and returns to the profile" do
    sign_in user

    post membership_invoice_checkouts_path, params: { invoice_id: invoice.id }

    expect(response).to redirect_to("https://checkout.stripe.com/membership")
    expect(checkout_args[:mode]).to eq("payment")
    expect(checkout_args[:subscription_data]).to be_nil
    expect(checkout_args[:metadata]).to eq({ membership_id: membership.id })
    expect(checkout_args[:payment_intent_data]).to eq({ metadata: { membership_id: membership.id } })
    expect(checkout_args[:line_items].size).to eq(1)
    expect(checkout_args[:line_items][0][:price_data][:unit_amount]).to eq(invoice.remaining_cost)
    expect(checkout_args[:line_items][0][:price_data]).not_to have_key(:recurring)
    expect(checkout_args[:success_url]).to eq(person_url(person, membership_invoice_checkout: "success"))
  end

  it "refuses another person's invoice" do
    sign_in create(:user, :with_person)

    post membership_invoice_checkouts_path, params: { invoice_id: invoice.id }

    expect(response).to redirect_to(root_path)
  end

  it "refuses an invoice with nothing to pay" do
    future = create(:membership_invoice, membership: membership,
      start_date: invoice.end_date + 1.day, end_date: invoice.end_date + 1.year)
    sign_in user

    post membership_invoice_checkouts_path, params: { invoice_id: future.id }

    expect(response).to redirect_to(person_path(person))
  end

  it "is refused while membership is disabled" do
    allow(Membership).to receive(:enabled?).and_return(false)
    sign_in user

    post membership_invoice_checkouts_path, params: { invoice_id: invoice.id }

    expect(response).to redirect_to(root_path)
  end
end
