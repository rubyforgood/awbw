module Admin
  class AhoyActivitiesController < Admin::BaseController
    helper_method :scoped_visits, :scoped_events

    def index
    end

    def visits
    end

    def charts
    end

    def recent
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

    private

    def time_range
      case params[:time_period]
      when "past_day"
        1.day.ago..Time.current
      when "past_week"
        1.week.ago..Time.current
      when "past_month"
        1.month.ago..Time.current
      when "past_year"
        1.year.ago..Time.current
      else
        nil # all_time
      end
    end

    def scoped_visits
      scope = Ahoy::Visit.all
      scope = scope.where(started_at: time_range) if time_range

      case params[:audience]
      when "visitors"
        scope = scope.where(user_id: nil)
      when "users"
        scope = scope.joins(:user).where(users: { super_user: false })
      when "staff"
        scope = scope.joins(:user).where(users: { super_user: true })
      end

      scope
    end

    def scoped_events
      scope = Ahoy::Event.all
      scope = scope.where(time: time_range) if time_range

      case params[:audience]
      when "visitors"
        scope = scope.where(user_id: nil)
      when "users"
        scope = scope.joins(:user).where(users: { super_user: false })
      when "staff"
        scope = scope.joins(:user).where(users: { super_user: true })
      end

      scope
    end
  end
end
