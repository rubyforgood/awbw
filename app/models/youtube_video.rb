class YoutubeVideo < ApplicationRecord
  include GlobalID::Identification
  include ActionText::Attachable

  validates :url, presence: true

  def video_id
    # Extract the video ID from a YouTube URL
    URI.parse(url).query&.split("&")&.find { |p| p.start_with?("v=") }&.split("=")&.last ||
      url.split("/").last
  end
end
