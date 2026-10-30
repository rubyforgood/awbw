require "rails_helper"

RSpec.describe "Membership invoice receipts", type: :request do
  let(:person) { create(:person) }
  let(:membership) { create(:membership, person: person) }
  let(:invoice) { create(:membership_invoice, membership: membership, cost_cents: 2_500) }

  before do
    create(:allocation, source: create(:payment, amount_cents: 2_500), allocatable: invoice, amount: 2_500)
  end

  it "shows invoice details to an admin" do
    sign_in create(:user, :admin)

    get receipt_membership_invoice_path(invoice)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Invoice details")
  end

  it "does not show invoice details to the member" do
    sign_in create(:user, person: person)

    get receipt_membership_invoice_path(invoice)

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("Invoice details")
  end
end
