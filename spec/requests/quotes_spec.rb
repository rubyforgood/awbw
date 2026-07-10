require "rails_helper"

RSpec.describe "/quotes", type: :request do
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  describe "GET /new" do
    it "renders the visibility card with the published flag" do
      get new_quote_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("admin-only bg-blue-100")
      expect(response.body).to include('name="quote[published]"')
      expect(response.body).to include(VisibilityFlagsHelper::FLAG_DEFINITIONS[:published][:description])
    end
  end
end
