module Home
  class StoriesController < ApplicationController
    def index
      authorize! :home
      @stories = authorized_scope(Story.published
                      .order(:title), with: HomePolicy)
                      .decorate

      render "home/stories/index"
    end
  end
end
