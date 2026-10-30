require "rails_helper"

RSpec.describe "Person billing portal", type: :request do
  let(:person) { create(:person) }
  let(:customer) { instance_double("Pay::Stripe::Customer") }
  let(:portal_session) { double(url: "https://billing.stripe.test/session") }

  before do
    allow_any_instance_of(Person).to receive(:stripe_payment_processor).and_return(customer)
    allow(customer).to receive(:billing_portal).and_return(portal_session)
    sign_in create(:user, person: person)
  end

  it "returns the member to their profile instead of the request referer" do
    post person_billing_portal_path(person),
      headers: { "Referer" => "https://attacker.example/phish" }

    expect(response).to redirect_to(portal_session.url)
    expect(customer).to have_received(:billing_portal).with(return_url: person_url(person))
  end
end
