class YoutubeAttachmentsController < ApplicationController
  def create
    video = YoutubeVideo.find_or_create_by(url: params[:url])

    render json: {
      video_id: video.video_id,
      sgid: video.attachable_sgid,
      title: "YouTube Video",
      canonical_url: video.url,
      thumbnail_url: "https://img.youtube.com/vi/#{video.video_id}/hqdefault.jpg"
    }
  end
end
