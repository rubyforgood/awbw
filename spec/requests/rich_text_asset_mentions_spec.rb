require "rails_helper"

RSpec.describe "/rich_text_asset_mentions", type: :request do
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  describe "GET /index" do
    it "returns an empty list when the sgid resolves to a decorated record that owns no rich text assets" do
      event = create(:event)
      sgid = event.decorate.to_sgid.to_s

      get rich_text_asset_mentions_path(format: :json, sgid: sgid, query: "1")

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq([])
    end

    it "returns an empty list when the sgid cannot be located" do
      get rich_text_asset_mentions_path(format: :json, sgid: "bogus", query: "1")

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq([])
    end
  end
end
