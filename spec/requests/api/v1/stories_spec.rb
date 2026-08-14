require "rails_helper"

RSpec.describe "Api::V1::Stories", type: :request do
  let!(:public_story) do
    create(:story, :published, :publicly_visible, title: "Public story")
  end

  let!(:public_featured_story) do
    create(:story, :published, :publicly_visible, :publicly_featured, :featured,
           title: "Public featured story")
  end

  # published but not publicly_visible — must never appear in the public API
  let!(:internal_story) do
    create(:story, :published, title: "Internal story")
  end

  # not published at all
  let!(:draft_story) do
    create(:story, :unpublished, :publicly_visible, title: "Draft story")
  end

  def json
    JSON.parse(response.body)
  end

  describe "GET /api/v1/stories" do
    it "returns only publicly visible stories, without authentication" do
      get "/api/v1/stories"

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/json")

      titles = json["stories"].map { |s| s["title"] }
      expect(titles).to contain_exactly("Public story", "Public featured story")
      expect(titles).not_to include("Internal story", "Draft story")
    end

    it "exposes the featured and publicly_featured flags on each story" do
      get "/api/v1/stories"

      featured = json["stories"].find { |s| s["title"] == "Public featured story" }
      plain    = json["stories"].find { |s| s["title"] == "Public story" }

      expect(featured).to include("featured" => true, "publicly_featured" => true, "published" => true)
      expect(plain).to include("featured" => false, "publicly_featured" => false)
    end

    it "includes pagination metadata" do
      get "/api/v1/stories"

      expect(json["meta"]).to include(
        "current_page" => 1,
        "per_page" => Api::V1::StoriesController::DEFAULT_PER_PAGE,
        "total_entries" => 2
      )
    end

    it "caps per_page at the maximum" do
      get "/api/v1/stories", params: { per_page: "9999" }

      expect(json["meta"]["per_page"]).to eq(Api::V1::StoriesController::MAX_PER_PAGE)
    end
  end

  describe "GET /api/v1/stories/:id" do
    it "returns a publicly visible story" do
      get "/api/v1/stories/#{public_story.id}"

      expect(response).to have_http_status(:ok)
      expect(json["story"]).to include(
        "id" => public_story.id,
        "title" => "Public story",
        "slug" => public_story.to_param
      )
    end

    it "groups the story's tags into categories (by type) and sectors" do
      story    = create(:story, :published, :publicly_visible, title: "Tagged story")
      age_type = create(:category_type, name: "AgeRange")
      category = create(:category, name: "6-12", category_type: age_type)
      sector   = create(:sector, name: "Domestic violence")
      create(:categorizable_item, category: category, categorizable: story)
      create(:sectorable_item, sector: sector, sectorable: story)

      get "/api/v1/stories/#{story.id}"

      tags = json["story"]["tags"]
      expect(tags["categories"]).to eq("Age range" => [ "6-12" ])
      expect(tags["sectors"]).to eq([ "Domestic violence" ])
    end

    it "404s for a story that is not publicly visible" do
      get "/api/v1/stories/#{internal_story.id}"

      expect(response).to have_http_status(:not_found)
      expect(json["error"]).to eq("Not found")
    end

    it "404s for an unknown id" do
      get "/api/v1/stories/0"

      expect(response).to have_http_status(:not_found)
    end
  end
end
