require "rails_helper"

RSpec.describe "/home/resources", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  describe "GET /home/resources" do
    it "shows a featured resource" do
      create(:resource, :published, :featured, title: "Visible Featured Resource")

      get home_resources_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Visible Featured Resource")
    end

    it "excludes a featured resource that is hidden from search" do
      create(:resource, :published, :featured, :hidden_from_search, title: "Hidden Featured Resource")

      get home_resources_path

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Hidden Featured Resource")
    end
  end
end
