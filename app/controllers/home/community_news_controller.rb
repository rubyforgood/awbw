module Home
  class CommunityNewsController < ApplicationController
    skip_before_action :authenticate_user!

    def index
      authorize! :home
      @community_news = authorized_scope(CommunityNews
                                              .published
                                              .order(created_at: :desc), with: HomePolicy).decorate

      render "home/community_news/index"
    end
  end
end
