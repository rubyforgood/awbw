module Home
  class StoriesController < ApplicationController
    skip_before_action :authenticate_user!

    def index
      authorize! :home
      @stories = authorized_scope(Story.published.not_funder_only.with_author_credit
                      .order(created_at: :desc), with: HomePolicy)
                      .decorate

      render "home/stories/index"
    end
  end
end
