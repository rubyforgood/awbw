module Home
  class VideoLibraryController < ApplicationController
    skip_before_action :authenticate_user!

    def index
      authorize! :home
      base = YoutubeVideo.where.not(youtube_url: [ nil, "" ]).order(position: :asc, created_at: :desc)
      @youtube_videos = authorized_scope(base, with: HomePolicy).decorate

      render "home/video_library/index"
    end
  end
end
