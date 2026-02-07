module Admin
  class AhoyActivitiesController < Admin::BaseController
    helper_method :scoped_visits, :scoped_events

    def index
      authorize! :ahoy_activity, to: :index?

      @users = params[:user_id].present? ? User.where(id: params[:user_id].to_s.split("--")) : nil

      page = params[:page].presence&.to_i || 1
      per_page = params[:per_page].presence&.to_i || 20

      scope = Ahoy::Event.includes(:user, :visit).order(time: :desc)

      # Only real content interactions (not search/filter noise)
      if params[:prefixes].present?
        prefixes = params[:prefixes].split("--").map(&:strip)
      else
        prefixes = nil # %w[ create update destroy auth ] # view browse print download
      end
      if prefixes.present?
        scope = scope.where(prefixes.map { |p| "ahoy_events.name LIKE ?" }.join(" OR "),
                            *prefixes.map { |p| "#{p}.%" })
      end

      # Filter by user (if viewing specific user activity)
      scope = scope.where(user: @users) if @users.present?

      # Time filter
      scope = scope.where(time: time_range) if time_range.present?

      if params[:from].present?
        from_time = Time.zone.parse(params[:from]).beginning_of_day
        scope = scope.where("ahoy_events.time >= ?", from_time)
      end

      if params[:to].present?
        to_time = Time.zone.parse(params[:to]).end_of_day
        scope = scope.where("ahoy_events.time <= ?", to_time)
      end

      # Filter by visit
      if params[:visit_id].present?
        scope = scope.where(visit_id: params[:visit_id])
      end

      @events = scope.paginate(page: page, per_page: per_page)
    end

    def visits
      authorize! :ahoy_activity, to: :visits?

      page     = params[:page].presence&.to_i || 1
      per_page = params[:per_page].presence&.to_i || 20

      scope = Ahoy::Visit
                .includes(:user)
                .left_joins(:events)
                .select("ahoy_visits.*, COUNT(ahoy_events.id) AS events_count")
                .group("ahoy_visits.id")
                .order(started_at: :desc)

      # Filter by user
      if params[:user_id].present?
        scope = scope.where(user_id: params[:user_id])
      end

      # Filter by visit
      if params[:visit_id].present?
        scope = scope.where(id: params[:visit_id])
      end

      # Date filtering
      if params[:from].present?
        from_time = Time.zone.parse(params[:from]).beginning_of_day
        scope = scope.where("ahoy_visits.started_at >= ?", from_time)
      end

      if params[:to].present?
        to_time = Time.zone.parse(params[:to]).end_of_day
        scope = scope.where("ahoy_visits.started_at <= ?", to_time)
      end

      @visits = scope.paginate(page: page, per_page: per_page)
    end

    def charts
      authorize! :ahoy_activity, to: :charts?
      @creation_velocity_data = creation_velocity_data
    end

    private

    def creation_velocity_data
      models = %w[workshop_idea story_idea workshop_log quote bookmark]

      base_scope = Ahoy::Event
                     .where("name LIKE 'create.%'")
                     .where(resource_type: models.map(&:classify))
                     .where("time >= ?", 6.months.ago)

      models.map do |model|
        {
          name: model.humanize.titleize.pluralize,
          data: base_scope
                  .where(name: "create.#{model}")
                  .group_by_day(:time)
                  .count
        }
      end.reject { |s| s[:data].empty? }
    end

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
