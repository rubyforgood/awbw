require "rails_helper"

RSpec.describe StoryDecorator do
  describe "#display_image" do
    it "shows the video's YouTube thumbnail over an uploaded image" do
      story = create(:story, youtube_url: "https://www.youtube.com/watch?v=abc123")
      create(:primary_asset, :with_file, owner: story)

      expect(story.reload.decorate.display_image).to eq("https://i.ytimg.com/vi/abc123/hqdefault.jpg")
    end

    it "shows the uploaded image when the YouTube link has no video id" do
      story = create(:story, youtube_url: "https://www.youtube.com/@awbworg")
      create(:primary_asset, :with_file, owner: story)

      expect(story.reload.decorate.display_image).to be_attached
    end

    it "falls back to the default image without a video" do
      story = build(:story, youtube_url: nil).decorate

      expect(story.display_image).to eq("theme_default.png")
    end
  end
end
