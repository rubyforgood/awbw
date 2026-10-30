require "rails_helper"

RSpec.describe "Membership terms", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:person) { create(:person) }
  let!(:membership) { create(:membership, person: person, cost_cents: 1_500) }

  before { sign_in admin }

  def update_membership(cost_dollars:)
    patch membership_path(membership), params: {
      membership: {
        start_date: membership.start_date.to_s,
        end_date: membership.end_date.to_s,
        cost_dollars: cost_dollars
      }
    }
  end

  it "rejects a non-numeric locked price" do
    update_membership(cost_dollars: "fifty")

    expect(response).to redirect_to(edit_membership_path(membership))
    expect(flash[:alert]).to match(/Enter the locked price as a number/)
    expect(membership.reload.cost_cents).to eq(1_500)
  end

  it "rejects a negative locked price" do
    update_membership(cost_dollars: "-50")

    expect(response).to redirect_to(edit_membership_path(membership))
    expect(membership.reload.cost_cents).to eq(1_500)
  end

  it "saves a valid locked price" do
    update_membership(cost_dollars: "50")

    expect(response).to redirect_to(membership_path(membership))
    expect(membership.reload.cost_cents).to eq(5_000)
  end

  it "clears the locked price when left blank" do
    update_membership(cost_dollars: "")

    expect(response).to redirect_to(membership_path(membership))
    expect(membership.reload.cost_cents).to be_nil
  end
end
