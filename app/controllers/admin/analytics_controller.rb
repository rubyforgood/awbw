module Admin
  class AnalyticsController < Admin::BaseController
    include AhoyViewTracking
    protect_from_forgery with: :null_session

    def index
      time_scope = apply_time_filter(params[:time_period])

      # Query Ahoy events for view counts within the time period
      @most_viewed_workshops = most_viewed_for_model(Workshop, time_scope).map(&:decorate)
      @most_viewed_workshop_variations = most_viewed_for_model(WorkshopVariation, time_scope).map(&:decorate)
      @most_viewed_resources = most_viewed_for_model(Resource, time_scope).map(&:decorate)
      @most_viewed_community_news = most_viewed_for_model(CommunityNews, time_scope).map(&:decorate)
      @most_viewed_stories = most_viewed_for_model(Story, time_scope).map(&:decorate)
      @most_viewed_quotes = most_viewed_for_model(Quote, time_scope).map(&:decorate)
      @most_viewed_tutorials = most_viewed_for_model(Tutorial, time_scope).map(&:decorate)
      @most_viewed_projects = most_viewed_for_model(Project, time_scope).map(&:decorate)
      @most_viewed_events = most_viewed_for_model(Event, time_scope).map(&:decorate)
      @most_viewed_facilitators = most_viewed_for_model(Facilitator, time_scope).map(&:decorate)

      @most_printed_workshops = most_printed_for_model(Workshop, time_scope).map(&:decorate)
      @most_downloaded_resources = most_downloaded_for_model(Resource, time_scope).map(&:decorate)

      @zero_engagement_workshops = zero_engagement_for_model(Workshop, time_scope).limit(10).decorate
      @zero_engagement_resources = zero_engagement_for_model(Resource, time_scope).limit(10).decorate

      @summary = {
        workshops: view_count_for_model(Workshop, time_scope),
        workshop_prints: print_count_for_model(Workshop, time_scope),
        resources: view_count_for_model(Resource, time_scope),
        resource_downloads: download_count_for_model(Resource, time_scope),
        community_news: view_count_for_model(CommunityNews, time_scope),
        stories: view_count_for_model(Story, time_scope),
        events: view_count_for_model(Event, time_scope),
        workshop_variations: view_count_for_model(WorkshopVariation, time_scope),
        quotes: view_count_for_model(Quote, time_scope),
        tutorials: view_count_for_model(Tutorial, time_scope),
        projects: view_count_for_model(Project, time_scope),
        facilitators: view_count_for_model(Facilitator, time_scope)
      }
    end

    private

    def apply_time_filter(time_period)
      time_ago = case time_period
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
      table_name_singular = model_class.table_name.singularize
      event_name = "view.#{table_name_singular}"
      # Get resource IDs with their view counts from Ahoy events
      # Using JSON_EXTRACT for MySQL - escape the $ in the path
      resource_ids_with_counts = Ahoy::Event
        .where(name: event_name)
        .then { |query| time_scope.call(query) }
        .group(Arel.sql("JSON_UNQUOTE(JSON_EXTRACT(properties, '$.resource_id'))"))
        .count
        .sort_by { |_id, count| -count }
        .first(10)

      # Fetch the actual records in the same order
      record_ids = resource_ids_with_counts.map { |id, _count| id.to_i }
      records = model_class.published.where(id: record_ids)
      
      # Create a hash for O(1) lookup of counts
      counts_by_id = resource_ids_with_counts.to_h { |id, count| [id.to_i, count] }
      
      # Sort records to match the order from the view counts and attach view_count
      id_positions = record_ids.each_with_index.to_h
      records.sort_by { |record| id_positions[record.id] || Float::INFINITY }.map do |record|
        record.define_singleton_method(:view_count) { counts_by_id[id] }
        record
      end
    end

    def most_printed_for_model(model_class, time_scope)
      table_name_singular = model_class.table_name.singularize
      event_name = "print.#{table_name_singular}"
      # Get resource IDs with their print counts from Ahoy events
      resource_ids_with_counts = Ahoy::Event
                                   .where(name: event_name)
                                   .then { |query| time_scope.call(query) }
                                   .group(Arel.sql("JSON_UNQUOTE(JSON_EXTRACT(properties, '$.resource_id'))"))
                                   .count
                                   .sort_by { |_id, count| -count }
                                   .first(10)

      # Fetch the actual records in the same order
      record_ids = resource_ids_with_counts.map { |id, _count| id.to_i }
      records = model_class.published.where(id: record_ids)
      
      # Create a hash for O(1) lookup of counts
      counts_by_id = resource_ids_with_counts.to_h { |id, count| [id.to_i, count] }
      
      # Sort records to match the order from the print counts and attach print_count
      id_positions = record_ids.each_with_index.to_h
      records.sort_by { |record| id_positions[record.id] || Float::INFINITY }.map do |record|
        record.define_singleton_method(:print_count) { counts_by_id[id] }
        record
      end
    end

    def most_downloaded_for_model(model_class, time_scope)
      table_name_singular = model_class.table_name.singularize
      event_name = "download.#{table_name_singular}"
      # Get resource IDs with their download counts from Ahoy events
      resource_ids_with_counts = Ahoy::Event
                                   .where(name: event_name)
                                   .then { |query| time_scope.call(query) }
                                   .group(Arel.sql("JSON_UNQUOTE(JSON_EXTRACT(properties, '$.resource_id'))"))
                                   .count
                                   .sort_by { |_id, count| -count }
                                   .first(10)

      # Fetch the actual records in the same order
      record_ids = resource_ids_with_counts.map { |id, _count| id.to_i }
      records = model_class.published.where(id: record_ids)
      
      # Create a hash for O(1) lookup of counts
      counts_by_id = resource_ids_with_counts.to_h { |id, count| [id.to_i, count] }
      
      # Sort records to match the order from the download counts and attach download_count
      id_positions = record_ids.each_with_index.to_h
      records.sort_by { |record| id_positions[record.id] || Float::INFINITY }.map do |record|
        record.define_singleton_method(:download_count) { counts_by_id[id] }
        record
      end
    end

    def zero_engagement_for_model(model_class, time_scope)
      table_name_singular = model_class.table_name.singularize
      event_name = "view.#{table_name_singular}"
      # Get IDs of resources that have been viewed in the time period
      viewed_ids = Ahoy::Event
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

    def view_count_for_model(model_class, time_scope)
      table_name_singular = model_class.table_name.singularize
      event_name = "view.#{table_name_singular}"
      time_scope.call(Ahoy::Event.where(name: event_name)).count
    end

    def print_count_for_model(model_class, time_scope)
      table_name_singular = model_class.table_name.singularize
      event_name = "print.#{table_name_singular}"
      time_scope.call(Ahoy::Event.where(name: event_name)).count
    end

    def download_count_for_model(model_class, time_scope)
      table_name_singular = model_class.table_name.singularize
      event_name = "download.#{table_name_singular}"
      time_scope.call(Ahoy::Event.where(name: event_name)).count
    end

    def print
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
  end
end
