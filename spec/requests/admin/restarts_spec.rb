require "rails_helper"

RSpec.describe "Admin restart", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:user) { create(:user) }

  before { allow(AppRestart).to receive(:call) }

  describe "GET /admin/restart" do
    it "shows an admin the restart button where restarting is available" do
      allow(AppRestart).to receive(:available?).and_return(true)
      sign_in admin

      get admin_restart_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Restart app")
      expect(response.body).to include(%(action="#{admin_restart_path}"))
    end

    it "explains where restarting isn't available" do
      sign_in admin

      get admin_restart_path

      expect(response.body).to include("isn't available in this environment")
    end

    it "turns away a non-admin" do
      sign_in user

      get admin_restart_path

      expect(response).to redirect_to(root_path)
    end
  end

  describe "POST /admin/restart" do
    it "restarts the app for an admin where restarting is available" do
      allow(AppRestart).to receive(:available?).and_return(true)
      sign_in admin

      post admin_restart_path

      expect(AppRestart).to have_received(:call)
      expect(response).to redirect_to(admin_restart_path)
      expect(flash[:notice]).to include("Restarting")
    end

    it "refuses where restarting isn't available" do
      sign_in admin

      post admin_restart_path

      expect(AppRestart).not_to have_received(:call)
      expect(flash[:alert]).to be_present
    end

    it "refuses a non-admin" do
      allow(AppRestart).to receive(:available?).and_return(true)
      sign_in user

      post admin_restart_path

      expect(AppRestart).not_to have_received(:call)
    end
  end
end
