module Dashboard
  class CommunityNewsController < ApplicationController
    def index
      authorize! :dashboard
      @community_news = authorized_scope(CommunityNews.includes(:bookmarks)
                                              .published
                                              .order(updated_at: :desc), with: DashboardPolicy).decorate

      render "dashboard/community_news/index"
    end
  end
end
