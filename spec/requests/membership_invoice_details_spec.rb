require "rails_helper"

RSpec.describe "Membership invoice details", type: :request do
  let(:person) { create(:person, :without_audit) }
  let(:membership) { create(:membership, person: person) }
  let!(:invoice) { create(:membership_invoice, membership: membership, cost_cents: 2_500) }

  it "saves the member's organization" do
    organization = create(:organization, name: "Acme Family Services")
    sign_in create(:user, :admin)

    patch membership_invoice_path(invoice),
      params: { membership_invoice: { organization_id: organization.id } }

    expect(invoice.reload.organization).to eq(organization)
  end
end
