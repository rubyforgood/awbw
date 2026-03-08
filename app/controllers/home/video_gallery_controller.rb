module Home
  class VideoGalleryController < ApplicationController
    skip_before_action :authenticate_user!

    def index
      authorize! :home
      base = VideoRecording.where(is_tutorial: false).where.not(youtube_url: [ nil, "" ]).order(position: :asc, created_at: :desc)
      @video_recordings = authorized_scope(base, with: HomePolicy).decorate

      render "home/video_gallery/index"
    end
  end
end
