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
      let(:admin) { create(:user, :admin) }
      let(:cache_key) { "featured_and_publicly_featured_workshop_ids" }

      around do |example|
        original_store = Rails.cache
        Rails.cache = ActiveSupport::Cache::MemoryStore.new
        example.run
      ensure
        Rails.cache = original_store
      end

      before do
        # Prime the cache with no featured workshops
        get home_workshops_path
        # Feature a workshop after the cache is set
        create(:workshop, :published, featured: true, windows_type: windows_type)
      end

      it "clears the cache for admins" do
        sign_in admin

        get home_workshops_path, params: { bust_cache: "true" }

        expect(response.body).not_to include("No workshops available right now.")
      end

      it "does not clear the cache for non-admins" do
        get home_workshops_path, params: { bust_cache: "true" }

        expect(response.body).to include("No workshops available right now.")
      end
    end
  end
end
