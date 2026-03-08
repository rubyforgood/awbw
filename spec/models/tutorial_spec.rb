require "rails_helper"

RSpec.describe VideoRecording, type: :model do
  describe ".search_by_params" do
    let!(:published_tutorial) { create(:video_recording, :published, title: "Getting Started Guide", rhino_body: "Welcome to AWBW") }
    let!(:draft_tutorial) { create(:video_recording, title: "Advanced Workshop Tips", rhino_body: "For experienced facilitators") }

    it "returns all when no params" do
      results = VideoRecording.search_by_params({})
      expect(results).to include(published_tutorial, draft_tutorial)
    end

    it "filters by search (title or body)" do
      results = VideoRecording.search_by_params(search: "Getting Started")
      expect(results).to include(published_tutorial)
      expect(results).not_to include(draft_tutorial)
    end

    it "filters by search matching body content" do
      results = VideoRecording.search_by_params(search: "facilitators")
      expect(results).to include(draft_tutorial)
      expect(results).not_to include(published_tutorial)
    end

    it "filters by title only" do
      results = VideoRecording.search_by_params(title: "Advanced")
      expect(results).to include(draft_tutorial)
      expect(results).not_to include(published_tutorial)
    end

    it "filters by published param" do
      results = VideoRecording.search_by_params(published: "true")
      expect(results).to include(published_tutorial)
      expect(results).not_to include(draft_tutorial)
    end

    it "chains search and published filters" do
      results = VideoRecording.search_by_params(search: "Guide", published: "true")
      expect(results).to include(published_tutorial)
      expect(results).not_to include(draft_tutorial)
    end
  end
end
