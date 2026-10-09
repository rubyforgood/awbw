require "rails_helper"

RSpec.describe "Admin::Settings", type: :request do
  let(:admin) { create(:user, :admin) }

  describe "GET show" do
    it "renders for an admin before any row exists" do
      sign_in admin

      get admin_settings_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("App settings")
    end

    it "names what the chosen organization supplies" do
      organization = create(:organization, name: "Portal Runner", tax_id: "12-3456789")
      Setting.create!(organization: organization)
      sign_in admin

      get admin_settings_path

      expect(response.body).to include("Portal Runner")
      expect(response.body).to include("12-3456789")
    end

    it "is denied to a non-admin" do
      sign_in create(:user)

      get admin_settings_path

      expect(response).not_to have_http_status(:ok)
    end
  end

  describe "PATCH update" do
    before { sign_in admin }

    it "creates the row on first save" do
      organization = create(:organization)

      patch admin_settings_path, params: { setting: { organization_id: organization.id, invoice_prefix: "AWBW" } }

      expect(response).to redirect_to(admin_settings_path)
      expect(response).to have_http_status(:see_other)
      expect(Setting.count).to eq(1)
      expect(Setting.app_organization).to eq(organization)
      expect(Setting.invoice_prefix).to eq("AWBW")
    end

    it "re-renders with errors on a malformed email" do
      patch admin_settings_path, params: { setting: { info_email: "nope" } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(Setting.count).to eq(0)
    end
  end
end
