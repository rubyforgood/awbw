module Admin
  class AnalyticsController < ApplicationController
    include AhoyTracking
    skip_before_action :authenticate_user!, only: :print

    def index
      authorize! :analytics, to: :index?
      @selected_audiences = Array(params[:audience]).reject(&:blank?).presence || %w[visitors users]
      time_scope = apply_time_filter(params[:time_period])

      # Query Ahoy events for view counts within the time period
      @most_viewed_workshops = decorate_with_counts(most_viewed_for_model(Workshop, time_scope), :view_count)
      @most_viewed_workshop_variations = decorate_with_counts(most_viewed_for_model(WorkshopVariation, time_scope), :view_count)
      @most_viewed_resources = decorate_with_counts(most_viewed_for_model(Resource, time_scope), :view_count)
      @most_viewed_community_news = decorate_with_counts(most_viewed_for_model(CommunityNews, time_scope), :view_count)
      @most_viewed_stories = decorate_with_counts(most_viewed_for_model(Story, time_scope), :view_count)
      @most_viewed_quotes = decorate_with_counts(most_viewed_for_model(Quote, time_scope), :view_count)
      @most_viewed_video_recordings = decorate_with_counts(most_viewed_for_model(VideoRecording, time_scope), :view_count)
      @most_viewed_organizations = decorate_with_counts(most_viewed_for_model(Organization, time_scope), :view_count)
      @most_viewed_events = decorate_with_counts(most_viewed_for_model(Event, time_scope), :view_count)
      @most_viewed_people = decorate_with_counts(most_viewed_for_model(Person, time_scope), :view_count)

      @most_printed_workshops = decorate_with_counts(most_printed_for_model(Workshop, time_scope), :print_count)
      @most_printed_resources = decorate_with_counts(most_printed_for_model(Resource, time_scope), :print_count)
      @most_printed_community_news = decorate_with_counts(most_printed_for_model(CommunityNews, time_scope), :print_count)
      @most_printed_stories = decorate_with_counts(most_printed_for_model(Story, time_scope), :print_count)
      # @most_printed_workshop_variations = decorate_with_counts(most_printed_for_model(WorkshopVariation, time_scope), :print_count)
      # @most_printed_quotes = decorate_with_counts(most_printed_for_model(Quote, time_scope), :print_count)
      # @most_printed_video_recordings = decorate_with_counts(most_printed_for_model(VideoRecording, time_scope), :print_count)
      # @most_printed_organizations = decorate_with_counts(most_printed_for_model(Organization, time_scope), :print_count)
      # @most_printed_events = decorate_with_counts(most_printed_for_model(Event, time_scope), :print_count)

      @most_downloaded_resources = decorate_with_counts(most_downloaded_for_model(Resource, time_scope), :download_count)

      @zero_engagement_workshops = zero_engagement_for_model(Workshop, time_scope).limit(10).decorate
      @zero_engagement_resources = zero_engagement_for_model(Resource, time_scope).limit(10).decorate

      # Single query to get all event counts grouped by name
      all_counts = time_scope.call(events_base_scope).group(:name).count

      @summary = {
        workshops: {
          views: all_counts["view.workshop"] || 0,
          prints: all_counts["print.workshop"] || 0
        },
        resources: {
          views: all_counts["view.resource"] || 0,
          prints: all_counts["print.resource"] || 0,
          downloads: all_counts["download.resource"] || 0
        },
        community_news: {
          views: all_counts["view.community_news"] || 0,
          prints: all_counts["print.community_news"] || 0
        },
        stories: {
          views: all_counts["view.story"] || 0,
          prints: all_counts["print.story"] || 0
        },
        events: {
          views: all_counts["view.event"] || 0,
          prints: all_counts["print.event"] || 0
        },
        workshop_variations: {
          views: all_counts["view.workshop_variation"] || 0,
          prints: all_counts["print.workshop_variation"] || 0
        },
        quotes: {
          views: all_counts["view.quote"] || 0,
          prints: all_counts["print.quote"] || 0
        },
        video_recordings: {
          views: all_counts["view.video_recording"] || 0,
          prints: all_counts["print.video_recording"] || 0
        },
        organizations: {
          views: all_counts["view.organization"] || 0,
          prints: all_counts["print.organization"] || 0
        },
        people: {
          views: all_counts["view.person"] || 0
        }
      }
    end

    def print
      authorize! :analytics, to: :print?

      return head :bad_request unless request.content_type&.include?("application/json")

      printable_models = {
        "Resource" => Resource,
        "Story" => Story,
        "Workshop" => Workshop,
        "CommunityNews" => CommunityNews
      }.freeze

      klass = printable_models[params[:printable_type]]
      return head :bad_request unless klass

      record = klass.find_by(id: params[:printable_id])
      return head :not_found unless record

      track_print(record)

      head :ok
    end


    private

    def events_base_scope
      return Ahoy::Event.all if (@selected_audiences & %w[visitors users staff]).size == 3

      allowed_user_ids = []
      allowed_user_ids << nil if @selected_audiences.include?("visitors")

      if @selected_audiences.include?("users")
        allowed_user_ids.concat(User.where(super_user: false).pluck(:id))
      end

      if @selected_audiences.include?("staff")
        allowed_user_ids.concat(User.where(super_user: true).pluck(:id))
      end

      return Ahoy::Event.none if allowed_user_ids.empty?

      Ahoy::Event.where(user_id: allowed_user_ids)
    end

    def apply_time_filter(time_period)
      time_ago = case time_period
      when "past_day"
        1.day.ago
      when "past_week"
        1.week.ago
      when "past_month"
        1.month.ago
      when "past_year"
        1.year.ago
      else
        nil
      end

      return ->(scope) { scope } if time_ago.nil?

      # Return appropriate lambda based on whether we're filtering events or records
      ->(scope) do
        time_column = scope.respond_to?(:klass) &&
        scope.klass == Ahoy::Event ? "time" : "created_at"
        scope.where("#{time_column} >= ?", time_ago)
      end
    end

    def most_viewed_for_model(model_class, time_scope)
      top_records_by_event(model_class, "view", time_scope, :view_count)
    end

    def most_printed_for_model(model_class, time_scope)
      top_records_by_event(model_class, "print", time_scope, :print_count)
    end

    def most_downloaded_for_model(model_class, time_scope)
      top_records_by_event(model_class, "download", time_scope, :download_count)
    end

    # Pushes ORDER BY / LIMIT into SQL instead of sorting in Ruby
    def top_records_by_event(model_class, action, time_scope, count_attr, limit = 10)
      event_name = "#{action}.#{model_class.table_name.singularize}"
      rid_sql = "JSON_UNQUOTE(JSON_EXTRACT(properties, '$.resource_id'))"

      rows = time_scope.call(events_base_scope.where(name: event_name))
        .select(Arel.sql("#{rid_sql} AS rid, COUNT(*) AS cnt"))
        .group(Arel.sql(rid_sql))
        .order(Arel.sql("cnt DESC"))
        .limit(limit)

      resource_ids_with_counts = rows.map { |r| [ r.rid.to_i, r.cnt ] }
      record_ids = resource_ids_with_counts.map(&:first)
      counts_by_id = resource_ids_with_counts.to_h

      records = model_class.published.where(id: record_ids)
      id_positions = record_ids.each_with_index.to_h

      records.sort_by { |record| id_positions[record.id] || Float::INFINITY }.map do |record|
        count = counts_by_id[record.id]
        record.instance_variable_set(:"@#{count_attr}", count)
        record.define_singleton_method(count_attr) { instance_variable_get(:"@#{count_attr}") }
        record
      end
    end

    def zero_engagement_for_model(model_class, time_scope)
      table_name_singular = model_class.table_name.singularize
      event_name = "view.#{table_name_singular}"
      # Get IDs of resources that have been viewed in the time period
      viewed_ids = events_base_scope
        .where(name: event_name)
        .then { |query| time_scope.call(query) }
        .distinct
        .pluck(Arel.sql("JSON_UNQUOTE(JSON_EXTRACT(properties, '$.resource_id'))"))
        .map(&:to_i)

      # Get resources created in time period that haven't been viewed
      time_scope.call(model_class.published)
        .where.not(id: viewed_ids)
        .order(created_at: :desc)
    end

    # Helper to decorate records while preserving count methods
    def decorate_with_counts(records_with_counts, count_method)
      records_with_counts.map do |record|
        # Get the count from the instance variable
        count = record.instance_variable_get("@#{count_method}")
        # Decorate the record
        decorated = record.decorate
        # Add the count method to the decorator
        decorated.define_singleton_method(count_method) { count }
        decorated
      end
    end
  end
end
