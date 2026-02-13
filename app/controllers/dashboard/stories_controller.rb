module Dashboard
  class StoriesController < ApplicationController
    def index
      authorize! :dashboard
      @stories = authorized_scope(Story.published
                      .order(:title), with: DashboardPolicy)
                      .decorate

      render "dashboard/stories/index"
    end
  end
end
