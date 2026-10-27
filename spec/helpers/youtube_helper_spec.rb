require "rails_helper"

RSpec.describe YoutubeHelper, type: :helper do
  describe "#youtube_video_id" do
    it "reads the id from watch and short links" do
      expect(helper.youtube_video_id("https://www.youtube.com/watch?v=abc123")).to eq("abc123")
      expect(helper.youtube_video_id("https://youtu.be/abc123")).to eq("abc123")
    end

    it "is nil for a blank, unparseable, or id-less URL" do
      expect(helper.youtube_video_id(nil)).to be_nil
      expect(helper.youtube_video_id("not a url")).to be_nil
      expect(helper.youtube_video_id("https://www.youtube.com/@awbworg")).to be_nil
      expect(helper.youtube_video_id("https://youtu.be/")).to be_nil
    end
  end

  describe "#youtube_embed_url" do
    it "builds a plain embed URL" do
      expect(helper.youtube_embed_url("https://youtu.be/abc123")).to eq("https://www.youtube.com/embed/abc123")
    end

    it "turns on the player's JS API when asked" do
      expect(helper.youtube_embed_url("https://youtu.be/abc123", js_api: true)).to eq("https://www.youtube.com/embed/abc123?enablejsapi=1")
    end
  end

  describe "#youtube_background_embed_url" do
    it "builds a muted, looping, controls-free autoplay embed" do
      url = helper.youtube_background_embed_url("https://www.youtube.com/watch?v=abc123")
      uri = URI.parse(url)

      expect("#{uri.host}#{uri.path}").to eq("www.youtube.com/embed/abc123")
      expect(Rack::Utils.parse_query(uri.query)).to include(
        "autoplay" => "1", "mute" => "1", "loop" => "1", "playlist" => "abc123", "controls" => "0", "playsinline" => "1"
      )
    end

    it "keeps a crafted id from adding its own player params" do
      url = helper.youtube_background_embed_url("https://www.youtube.com/watch?v=abc%26mute%3D0")

      expect(Rack::Utils.parse_query(URI.parse(url).query)["mute"]).to eq("1")
    end

    it "is nil without a video id" do
      expect(helper.youtube_background_embed_url("https://www.youtube.com/@awbworg")).to be_nil
    end
  end

  describe "#youtube_thumbnail_url" do
    it "points at the video's YouTube thumbnail" do
      expect(helper.youtube_thumbnail_url("https://youtu.be/abc123")).to eq("https://i.ytimg.com/vi/abc123/hqdefault.jpg")
    end

    it "is nil without a video id" do
      expect(helper.youtube_thumbnail_url("https://www.youtube.com/@awbworg")).to be_nil
    end
  end
end
