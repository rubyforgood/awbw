require "rails_helper"

RSpec.describe "Membership invoice documents", type: :request do
  let(:person) { create(:person, :without_audit) }
  let(:membership) { create(:membership, person: person) }
  let(:invoice) do
    create(:membership_invoice, membership: membership, cost_cents: 2_500,
      start_date: Date.new(2027, 3, 1), end_date: Date.new(2028, 2, 29),
      organization: create(:organization, name: "Acme Family Services"))
  end

  it "prints the period, the member's organization and AWBW's W-9" do
    w9 = create(:resource, role: "w9", title: "W-9")
    sign_in create(:user, :admin)

    get membership_invoice_path(invoice)

    expect(response.body).to include("Mar 1, 2027 – Feb 29, 2028")
    expect(response.body).to include("Acme Family Services")
    expect(response.body).to include("W-9 (PDF)")
    expect(response.body).to include(resource_path(w9))
  end
end
