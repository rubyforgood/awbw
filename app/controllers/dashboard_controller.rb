class DashboardController < ApplicationController
  include AdminDashboardCardsHelper

  def index
    workshops = Workshop.includes(:sectors, :categories, :windows_type, :primary_asset, :gallery_assets)
                        .featured
                        .published
                        .decorate
    @workshops = workshops.sort { |x, y| Date.parse(y.date) <=> Date.parse(x.date) }

    @resources = Resource.includes(:windows_type, :primary_asset, :gallery_assets)
                         .featured
                         .published
                         .by_most_viewed(6)
                         .order(position: :asc, created_at: :desc)
                         .decorate
    @stories = Story.includes(:windows_type, :primary_asset, :gallery_assets)
                    .featured
                    .published
                    .order(:title)
                    .decorate
    @community_news = CommunityNews.includes(:windows_type, :primary_asset, :gallery_assets)
                                   .featured
                                   .published
                                   .order(updated_at: :desc)
                                   .decorate
    @events = Event.includes(:event_registrations, :primary_asset, :gallery_assets)
                   .featured
                   .published
                   .order(:start_date)
                   .decorate
  end

  def admin
    return redirect_to authenticated_root_path, alert: "You do not have permission." unless current_user.super_user?

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
