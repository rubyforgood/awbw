class DashboardController < ApplicationController
  include AdminDashboardCardsHelper
  skip_before_action :authenticate_user!

  def index
    authorize! :dashboard
    if turbo_frame_request?
      case turbo_frame_request_id
      when "dashboard_workshops"
        ids = Rails.cache.fetch("featured_and_public_featured_workshop_ids", expires_in: 1.year) do
          Workshop.featured_or_public_featured.pluck(:id)
        end

        base_scope = Workshop.includes(:bookmarks, :windows_type, :primary_asset)
                          .where(id: ids)

        @workshops = authorized_scope(base_scope, with: DashboardPolicy).decorate
        @workshops = @workshops.sort { |x, y| Date.parse(y.date) <=> Date.parse(x.date) }
      when "dashboard_resources"
        @resources = authorized_scope(Resource.includes(:bookmarks, :primary_asset, :downloadable_asset)
                             .published
                             .order(position: :asc, created_at: :desc), with: DashboardPolicy)
                             .decorate

      when "dashboard_stories"
        @stories = authorized_scope(Story.published
                        .order(:title), with: DashboardPolicy)
                        .decorate
      when "dashboard_community_news"
        @community_news = authorized_scope(CommunityNews.includes(:bookmarks)
                                                        .published
                                                        .order(updated_at: :desc), with: DashboardPolicy)
                            .decorate

      when "dashboard_events"
        @events = authorized_scope(Event.includes(:bookmarks, :primary_asset)
                       .published
                       .order(:start_date), with: DashboardPolicy)
                       .decorate
      end
      render :index_lazy
    else
      render :index
    end
  end

  def admin
    return redirect_to root_path, alert: "You do not have permission." unless current_user.super_user?

    @system_cards       = system_cards
    @user_content_cards = user_content_cards
    @reference_cards    = reference_cards
  end
end
