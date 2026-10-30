require "rails_helper"

RSpec.describe "Admin membership view", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:person) { create(:person, :without_audit) }
  let!(:membership) { create(:membership, person: person) }
  let!(:invoice) do
    create(:membership_invoice, membership: membership, start_date: Date.current,
      end_date: Date.current + 1.year - 1.day, cost_cents: 10_000)
  end

  before { sign_in admin }

  it "shows the membership card without member payment or card controls" do
    get person_path(person)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Annual membership")
    expect(response.body).not_to include("Pay now")
    expect(response.body).not_to include("Subscribe")
    expect(response.body).not_to include("Turn on automatic payments")
    expect(response.body).not_to include("Add a card & turn on automatic payments")
    expect(response.body).not_to include("Manage card")
  end

  it "does not let an admin open the member's billing portal" do
    post person_billing_portal_path(person)

    expect(response).to redirect_to(root_path)
  end
end
