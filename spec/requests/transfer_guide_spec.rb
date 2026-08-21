require "rails_helper"

RSpec.describe "TransferGuide", type: :request do
  it "renders the guide for an admin" do
    sign_in create(:user, :admin)

    get transfer_guide_path

    expect(response).to have_http_status(:success)
    expect(response.body).to include("Transferring a registration")
    expect(response.body).to include("Transferred in")
    expect(response.body).to include("Transferred out")
    # The inline HTML mockups render (not just the descriptive text).
    expect(response.body).to include("Pay with credit card")
    expect(response.body).to include("From original registration")
  end

  it "redirects a non-admin away" do
    sign_in create(:user)

    get transfer_guide_path

    expect(response).to redirect_to(root_path)
  end
end
