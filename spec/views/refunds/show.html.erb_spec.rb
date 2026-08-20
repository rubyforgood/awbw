require "rails_helper"

RSpec.describe "refunds/show", type: :view do
  let(:payment) { create(:payment, amount_cents: 5000) }
  let(:person) { create(:person) }
  let(:refund) { create(:refund, refundable: payment, recipient: person, amount_cents: 1000, method: "check") }

  before do
    assign(:refund, refund)
    render
  end

  it "shows refund details" do
    expect(rendered).to have_content("$10")
    expect(rendered).to have_content("Check")
    expect(rendered).to have_content(person.name)
  end

  it "links to payment" do
    expect(rendered).to have_link("Payment", href: payment_path(payment))
    expect(rendered).to have_link("View payment", href: payment_path(payment))
  end
end
