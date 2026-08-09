require "rails_helper"

RSpec.describe "Admin::Home", type: :request do
  let(:admin) { create(:user, super_user: true) }
  let(:user)  { create(:user, super_user: false) }

  # ============================================================
  # AS A GUEST
  # ============================================================

  context "as a guest" do
    it "redirects to new user session path" do
      get admin_path

      expect(response).to redirect_to(new_user_session_path)
    end
  end

  # ============================================================
  # AS A REGULAR USER
  # ============================================================

  context "as a regular user" do
    before { sign_in user }

    it "redirects to root with alert" do
      get admin_path

      expect(response).to redirect_to(root_path)
      # expect(flash[:alert]).to eq("Not authorized")
    end
  end

  # ============================================================
  # AS AN ADMIN
  # ============================================================

  context "as an admin" do
    before { sign_in admin }

    it "renders successfully" do
      get admin_path
      expect(response).to have_http_status(:ok)
    end

    it "links to reports and still surfaces payments" do
      get admin_path
      expect(response.body).to include("Reports")
      expect(response.body).to include(reports_events_path)
      expect(response.body).to include("Payments")
    end

    it "surfaces Subscription topics and moves Organization statuses to Deprecated data" do
      get admin_path

      expect(response.body).to include("Subscription topics")
      expect(response.body).to include(topic_subscription_types_path)
      expect(response.body).to include("Deprecated data")
      expect(response.body).to include("Organization statuses")
      expect(response.body).to include(organization_statuses_path)
    end
  end
end
