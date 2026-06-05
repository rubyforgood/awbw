module Home
  class StoriesController < ApplicationController
    skip_before_action :authenticate_user!

    def index
      authorize! :home
      @stories = authorized_scope(Story.published
                      .order(:position), with: HomePolicy)
                      .decorate

      render "home/stories/index"
    end
  end
end
