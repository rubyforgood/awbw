require "rails_helper"

RSpec.describe StoryDecorator do
  describe "#display_image" do
    it "shows the video's YouTube thumbnail when no image is uploaded" do
      story = build(:story, youtube_url: "https://www.youtube.com/watch?v=abc123").decorate

      expect(story.display_image).to eq("https://i.ytimg.com/vi/abc123/hqdefault.jpg")
    end

    it "prefers an uploaded image over the video thumbnail" do
      story = create(:story, youtube_url: "https://www.youtube.com/watch?v=abc123")
      create(:primary_asset, :with_file, owner: story)

      expect(story.reload.decorate.display_image).to be_attached
    end

    it "falls back to the default image without a video" do
      story = build(:story, youtube_url: nil).decorate

      expect(story.display_image).to eq("theme_default.png")
    end
  end
end
