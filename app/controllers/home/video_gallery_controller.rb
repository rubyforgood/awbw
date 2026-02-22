module Home
  class VideoGalleryController < ApplicationController
    skip_before_action :authenticate_user!

    def index
      authorize! :home
      @tutorials = authorized_scope(Tutorial.where.not(youtube_url: [nil, ""])
                       .order(position: :asc, created_at: :desc), with: HomePolicy)
                       .decorate

      render "home/video_gallery/index"
    end
  end
end
