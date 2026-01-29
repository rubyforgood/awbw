class DashboardController < ApplicationController
  include AdminDashboardCardsHelper
  skip_before_action :authenticate_user!

  def index
    authorize! :dashboard
    if turbo_frame_request?
      case turbo_frame_request_id
      when "dashboard_workshops"
        ids = Rails.cache.fetch("featured_and_visitor_featured_workshop_ids", expires_in: 1.year) do
          Workshop.featured_or_visitor_featured.pluck(:id)
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
        @community_news = authorized_scope(CommunityNews.published
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

  def recent_activities
    @user = (current_user.super_user? && params[:user_id].present?) ? User.find(params[:user_id]) : current_user
    if params[:user_id] && params[:user_id].empty?
      recent = []
      recent.concat(User.order(updated_at: :desc).limit(10))
      recent.concat(Facilitator.order(updated_at: :desc).limit(10))
      recent.concat(Banner.order(updated_at: :desc).limit(10))
      recent.concat(Faq.order(updated_at: :desc).limit(10))
      recent.concat(Event.order(updated_at: :desc).limit(10))
      recent.concat(EventRegistration.order(updated_at: :desc).limit(10))
      recent.concat(Workshop.order(updated_at: :desc).limit(10))
      recent.concat(WorkshopIdea.order(updated_at: :desc).limit(10))
      recent.concat(WorkshopLog.order(updated_at: :desc).limit(10))
      recent.concat(WorkshopVariation.order(updated_at: :desc).limit(10))
      recent.concat(Story.order(updated_at: :desc).limit(10))
      recent.concat(StoryIdea.order(updated_at: :desc).limit(10))
      recent.concat(Quote.order(updated_at: :desc).limit(10))
      recent.concat(Resource.order(updated_at: :desc).limit(10))
      recent.concat(Report.where(owner_type: "MonthlyReport").order(updated_at: :desc).limit(10))
      # recent.concat(Report.where(owner_id: 7).order(updated_at: :desc).limit(10)) # TODO: remove hard-coded
      recent.concat(Address.order(updated_at: :desc).limit(10))
      recent.concat(Bookmark.order(updated_at: :desc).limit(10))
      recent.concat(Category.order(updated_at: :desc).limit(10))
      recent.concat(CommunityNews.order(updated_at: :desc).limit(10))
      recent.concat(Notification.order(updated_at: :desc).limit(10))
      recent.concat(Project.order(updated_at: :desc).limit(10))
      recent.concat(ProjectStatus.order(updated_at: :desc).limit(10))
      recent.concat(ProjectObligation.order(updated_at: :desc).limit(10))
      recent.concat(ProjectUser.order(updated_at: :desc).limit(10))
      recent.concat(Sector.order(updated_at: :desc).limit(10))
      recent.concat(WindowsType.order(updated_at: :desc).limit(10))

      # Sort by the most recent timestamp (updated_at preferred, fallback to created_at)
      recent_activities = recent.sort_by { |item|
        item.try(:updated_at) || item.created_at }
                                 .reverse.first(10 * 8)
    else
      recent_activities = @user.recent_activity(params[:limit] || 20)
    end
    @recent_activities = recent_activities
                           .paginate(page: params[:page],
                                     per_page: params[:per_page] || 20)
  end
end
