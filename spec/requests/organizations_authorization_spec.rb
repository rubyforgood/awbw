require "rails_helper"

RSpec.describe "Organizations authorization", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:regular_user) { create(:user) }

  let!(:organization_status) { create(:organization_status, name: "Active") }
  let!(:organization) { create(:organization, organization_status: organization_status) }

  describe "GET /organizations" do
    context "as a visitor" do
      it "redirects to root" do
        get organizations_path
        expect(response).to redirect_to(root_path)
      end
    end

    context "as a regular user" do
      before { sign_in regular_user }

      it "redirects to root" do
        get organizations_path
        expect(response).to redirect_to(root_path)
      end
    end

    context "as an admin" do
      before { sign_in admin }

      it "renders successfully" do
        get organizations_path
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "GET /organizations/:id" do
    context "as a visitor" do
      it "redirects to root" do
        get organization_path(organization)
        expect(response).to redirect_to(root_path)
      end
    end

    context "as a regular user" do
      before { sign_in regular_user }

      it "redirects to root" do
        get organization_path(organization)
        expect(response).to redirect_to(root_path)
      end
    end

    context "as an admin" do
      before { sign_in admin }

      it "renders successfully" do
        get organization_path(organization)
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
