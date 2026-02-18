module Admin
  class AhoyActivitiesController < ApplicationController
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

      # Filter by resource type and ID
      if params[:resource_type].present?
        scope = scope.where(resource_type: params[:resource_type])
      end

      if params[:resource_id].present?
        scope = scope.where(resource_id: params[:resource_id])
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
      prepare_chart_data
    end

    private

    def prepare_chart_data
      events = scoped_events

      # Workshop filter/search categories - pluck once, reuse for both type and name charts
      ws_categories_raw = events
        .where(name: ["filter.workshops", "search.workshops"])
        .pluck(Arel.sql("JSON_EXTRACT(properties, '$.filters.categories')"))
        .flat_map { |arr| JSON.parse(arr) rescue [] }

      @ws_category_types = ws_categories_raw
        .map { |c| c["type"] }.compact.tally
        .sort_by { |_k, v| -v }.first(10).to_h

      @ws_category_names = ws_categories_raw
        .map { |c| c["name"] }.compact.tally
        .sort_by { |_k, v| -v }.first(15).to_h

      # Workshop filter/search sectors
      @ws_sectors = events
        .where(name: ["filter.workshops", "search.workshops"])
        .pluck(Arel.sql("JSON_EXTRACT(properties, '$.filters.sectors')"))
        .flat_map { |arr| JSON.parse(arr) rescue [] }
        .map { |s| s["name"] }.compact.tally
        .sort_by { |_k, v| -v }.first(10).to_h

      # Workshop keyword searches
      ws_search = events.where(name: "search.workshops")

      @ws_search_titles = ws_search
        .pluck(Arel.sql("JSON_UNQUOTE(JSON_EXTRACT(properties, '$.keywords.title'))"))
        .compact.reject(&:blank?).tally
        .sort_by { |_k, v| -v }.first(10).to_h

      @ws_search_authors = ws_search
        .pluck(Arel.sql("JSON_UNQUOTE(JSON_EXTRACT(properties, '$.keywords.author'))"))
        .compact.reject(&:blank?).tally
        .sort_by { |_k, v| -v }.first(10).to_h

      @ws_search_full_text = ws_search
        .pluck(Arel.sql("JSON_UNQUOTE(JSON_EXTRACT(properties, '$.keywords.full_text'))"))
        .compact.reject(&:blank?).map(&:downcase).tally
        .sort_by { |_k, v| -v }.first(10).to_h

      # Windows types - batch lookup
      wt_ids = events
        .where(name: ["filter.workshops", "search.workshops"])
        .pluck(Arel.sql("JSON_EXTRACT(properties, '$.filters.windows_types')"))
        .flat_map { |arr| JSON.parse(arr) rescue [] }
      wt_names = WindowsType.where(id: wt_ids.uniq).pluck(:id, :short_name).to_h
      @ws_windows_types = wt_ids
        .map { |id| wt_names[id] }.compact.tally
        .sort_by { |_k, v| -v }.first(10).to_h

      # Zero-result searches
      @ws_zero_results = events
        .where("name LIKE 'search_zero.%'")
        .pluck(Arel.sql("JSON_UNQUOTE(JSON_EXTRACT(properties, '$.query'))"))
        .compact.reject(&:blank?).tally
        .sort_by { |_k, v| -v }.first(10).to_h

      # Workshop funnel - batch count
      ws_funnel_names = [
        "search.workshops", "filter.workshops",
        "view.workshop", "print.workshop", "download.workshop"
      ]
      ws_funnel_counts = events.where(name: ws_funnel_names).group(:name).count
      @ws_funnel = {
        "Keyword search" => ws_funnel_counts["search.workshops"] || 0,
        "Checkbox filter" => ws_funnel_counts["filter.workshops"] || 0,
        "View" => ws_funnel_counts["view.workshop"] || 0,
        "Print" => ws_funnel_counts["print.workshop"] || 0,
        "Download" => ws_funnel_counts["download.workshop"] || 0
      }

      # Resource search keywords
      @rs_keywords = events
        .where(name: "search.resources")
        .pluck(Arel.sql("JSON_UNQUOTE(JSON_EXTRACT(properties, '$.keywords.full_text'))"))
        .compact.reject(&:blank?).map(&:downcase).tally
        .sort_by { |_k, v| -v }.first(12).to_h

      # Resource filter kinds
      @rs_kinds = events
        .where(name: "filter.resources")
        .pluck(Arel.sql("JSON_UNQUOTE(JSON_EXTRACT(properties, '$.filters.kind'))"))
        .compact.reject(&:blank?).tally
        .sort_by { |_k, v| -v }.to_h

      # Resource funnel - batch count
      rs_funnel_names = [
        "search.resources", "filter.resources",
        "view.resource", "print.resource", "download.resource"
      ]
      rs_funnel_counts = events.where(name: rs_funnel_names).group(:name).count
      @rs_funnel = {
        "Keyword search" => rs_funnel_counts["search.resources"] || 0,
        "Kind filter" => rs_funnel_counts["filter.resources"] || 0,
        "View" => rs_funnel_counts["view.resource"] || 0,
        "Print" => rs_funnel_counts["print.resource"] || 0,
        "Download" => rs_funnel_counts["download.resource"] || 0
      }

      # Tagging sectors and categories
      tagging_events = events.where(name: "browse.taggings")
      tagging_count = tagging_events.count

      @tagging_sectors = tagging_events
        .pluck(Arel.sql("JSON_EXTRACT(properties, '$.sectors')"))
        .flat_map { |arr| JSON.parse(arr) rescue [] }
        .tally.sort_by { |_k, v| -v }.first(15).to_h

      @tagging_categories = tagging_events
        .pluck(Arel.sql("JSON_EXTRACT(properties, '$.categories')"))
        .flat_map { |arr| JSON.parse(arr) rescue [] }
        .tally.sort_by { |_k, v| -v }.first(15).to_h

      # User discovery funnel - batch with LIKE patterns
      @discovery_funnel = {
        "Views" => events.where("name LIKE 'view.%'").count,
        "Prints" => events.where("name LIKE 'print.%'").count,
        "Downloads" => events.where("name LIKE 'download.%'").count,
        "Keyword searches" => events.where("name LIKE 'search.%'").count,
        "Checkbox filters" => events.where("name LIKE 'filter.%'").count,
        "Taggings" => tagging_count
      }

      # Content discovery pie chart - reuse cached counts
      @content_discovery = {
        "Keyword searches" => ws_funnel_counts["search.workshops"] || 0,
        "Checkbox filters" => ws_funnel_counts["filter.workshops"] || 0,
        "Tagging pages" => tagging_count
      }
    end

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
