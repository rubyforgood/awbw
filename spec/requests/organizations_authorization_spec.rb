require "rails_helper"

RSpec.describe "Organizations authorization", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:regular_user) { create(:user) }

  let!(:organization_status) { create(:organization_status, name: "Active") }
  let!(:organization) { create(:organization, organization_status: organization_status) }

  describe "GET /organizations" do
    context "as a visitor" do
      it "redirects to new user session path" do
        get organizations_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "as a regular user" do
      before { sign_in regular_user }

      it "renders the preview outside production" do
        get organizations_path
        expect(response).to have_http_status(:ok)
      end

      it "redirects to root in production" do
        allow(Rails.env).to receive(:production?).and_return(true)
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
      it "redirects to new user session path" do
        get organization_path(organization)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "as a regular user" do
      before { sign_in regular_user }

      it "redirects to root for an unpublished organization" do
        get organization_path(organization)
        expect(response).to redirect_to(root_path)
      end

      context "with a published organization" do
        before { create(:affiliation, organization: organization) }

        it "renders the preview outside production" do
          get organization_path(organization)
          expect(response).to have_http_status(:ok)
        end

        it "redirects to root in production" do
          allow(Rails.env).to receive(:production?).and_return(true)
          get organization_path(organization)
          expect(response).to redirect_to(root_path)
        end
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
