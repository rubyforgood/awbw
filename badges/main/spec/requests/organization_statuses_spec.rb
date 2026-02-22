require "rails_helper"

RSpec.describe "OrganizationStatuses", type: :request do
  let(:admin)        { create(:user, :admin) }
  let(:regular_user) { create(:user) }
  let!(:status)      { create(:organization_status, name: "Active") }

  let(:valid_params)   { { organization_status: { name: "New Status" } } }
  let(:invalid_params) { { organization_status: { name: nil } } }

  # --------------------------------------------------
  # ADMIN ACCESS
  # --------------------------------------------------
  describe "admin access" do
    before { sign_in admin }

    it "loads index" do
      get organization_statuses_path
      expect(response).to have_http_status(:ok)
    end

    it "loads show" do
      get organization_status_path(status)
      expect(response).to have_http_status(:ok)
    end

    it "loads new" do
      get new_organization_status_path
      expect(response).to have_http_status(:ok)
    end

    it "loads edit" do
      get edit_organization_status_path(status)
      expect(response).to have_http_status(:ok)
    end

    it "creates record" do
      expect {
        post organization_statuses_path, params: valid_params
      }.to change(OrganizationStatus, :count).by(1)

      expect(response).to redirect_to(organization_status_path(OrganizationStatus.last))
    end

    it "rejects invalid create" do
      post organization_statuses_path, params: invalid_params
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "updates record" do
      patch organization_status_path(status),
            params: { organization_status: { name: "Updated" } }

      expect(response).to redirect_to(organization_status_path(status))
      expect(status.reload.name).to eq("Updated")
    end

    it "destroys record" do
      expect {
        delete organization_status_path(status)
      }.to change(OrganizationStatus, :count).by(-1)

      expect(response).to redirect_to(organization_statuses_path)
    end
  end

  # --------------------------------------------------
  # REGULAR USER ACCESS (BLOCKED)
  # --------------------------------------------------
  describe "regular user restrictions" do
    before { sign_in regular_user }

    it "cannot access index" do
      get organization_statuses_path
      expect(response).to redirect_to(root_path)
    end

    it "cannot access show" do
      get organization_status_path(status)
      expect(response).to redirect_to(root_path)
    end

    it "cannot access new" do
      get new_organization_status_path
      expect(response).to redirect_to(root_path)
    end

    it "cannot create" do
      post organization_statuses_path, params: valid_params
      expect(response).to redirect_to(root_path)
    end

    it "cannot access edit" do
      get edit_organization_status_path(status)
      expect(response).to redirect_to(root_path)
    end

    it "cannot update" do
      patch organization_status_path(status), params: valid_params
      expect(response).to redirect_to(root_path)
    end

    it "cannot destroy" do
      delete organization_status_path(status)
      expect(response).to redirect_to(root_path)
    end
  end

  # --------------------------------------------------
  # GUEST BLOCKED
  # --------------------------------------------------
  describe "unauthenticated access" do
    it "redirects to root" do
      get organization_statuses_path
      expect(response).to redirect_to(root_path)
    end
  end
end
