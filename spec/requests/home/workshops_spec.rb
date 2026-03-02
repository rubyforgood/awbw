require "rails_helper"

RSpec.describe "/home/workshops", type: :request do
  let(:user) { create(:user) }
  let!(:windows_type) { create(:windows_type) }

  before { sign_in user }

  describe "GET /home/workshops" do
    it "returns featured workshops" do
      workshop = create(:workshop, :published, featured: true, windows_type: windows_type)

      get home_workshops_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(workshop.title)
    end

    it "does not return unfeatured workshops" do
      create(:workshop, :published, featured: false, windows_type: windows_type)

      get home_workshops_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("No workshops available right now.")
    end

    context "with bust_cache=true" do
      it "clears and repopulates the featured workshop cache" do
        # Prime the cache with no featured workshops
        get home_workshops_path
        expect(response.body).to include("No workshops available right now.")

        # Feature a workshop after the cache is set
        create(:workshop, :published, featured: true, windows_type: windows_type)

        # Without bust_cache, stale cache returns no workshops
        get home_workshops_path
        expect(response.body).to include("No workshops available right now.")

        # With bust_cache=true, the cache is cleared and workshops appear
        get home_workshops_path, params: { bust_cache: "true" }
        expect(response.body).not_to include("No workshops available right now.")
      end
    end
  end
end
