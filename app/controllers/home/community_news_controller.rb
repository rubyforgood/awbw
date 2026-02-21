module Home
  class CommunityNewsController < ApplicationController
    def index
      authorize! :home
      @community_news = authorized_scope(CommunityNews
                                              .published
                                              .order(updated_at: :desc), with: HomePolicy).decorate

      render "home/community_news/index"
    end
  end
end
