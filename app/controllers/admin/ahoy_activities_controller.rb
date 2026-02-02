module Admin
  class AhoyActivitiesController < Admin::BaseController
    helper_method :scoped_visits, :scoped_events

    def index
      if current_user.super_user?
        if params.key?(:user_id) && params[:user_id].present?
          @user = User.find(params[:user_id])
        elsif params.key?(:user_id) # param exists but blank
          @user = nil
        else
          @user = current_user
        end
      else
        @user = current_user
      end

      page = params[:page].presence&.to_i || 1
      per_page = params[:per_page].presence&.to_i || 20

      scope = Ahoy::Event
                .includes(:user, :visit)
                .order(time: :desc)

      # Filter by user (if viewing specific user activity)
      scope = scope.where(user: @user) if params[:user_id].present?

      # Time filter
      scope = scope.where(time: time_range) if time_range.present?

      # Only real content interactions (not search/filter noise)
      prefixes = %w[ create update destroy auth ] # view browse print download
      scope = scope.where(
        prefixes.map { |p| "ahoy_events.name LIKE ?" }.join(" OR "),
        *prefixes.map { |p| "#{p}.%" }
      )

      # Pagination happens on events
      events = scope.paginate(page:, per_page:)

      # Convert events → real domain records wrapped in presenter
      @recent_activities = WillPaginate::Collection.create(
        events.current_page,
        events.per_page,
        events.total_entries
      ) do |pager|
        pager.replace(events.map { |event| ActivityPresenter.new(event) })
      end
    end

    def visits
    end

    def charts
    end

    private

    def scoped_visits
      scope = Ahoy::Visit.all
      scope = scope.where(started_at: time_range) if time_range

      case params[:audience]
      when "visitors"
        scope = scope.where(user_id: nil)
      when "users"
        scope = scope.includes(:user).joins(:user).where(users: { super_user: false })
      when "staff"
        scope = scope.includes(:user).joins(:user).where(users: { super_user: true })
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
        scope = scope.includes(:user).joins(:user).where(users: { super_user: false })
      when "staff"
        scope = scope.includes(:user).joins(:user).where(users: { super_user: true })
      end

      scope
    end

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

    def tracked_activity_conditions(scope)
      prefixes = %w[create update destroy view print download]

      conditions = prefixes.map { |p| scope.arel_table[:name].matches("#{p}.%") }
      conditions.inject { |memo, cond| memo.or(cond) }
    end
  end
end
