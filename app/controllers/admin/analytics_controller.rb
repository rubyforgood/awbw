module Admin
  class AnalyticsController < Admin::BaseController
    include AhoyViewTracking
    protect_from_forgery with: :null_session

    def index
      time_scope = apply_time_filter(params[:time_period])

      # Query Ahoy events for view counts within the time period
      @most_viewed_workshops = decorate_with_counts(most_viewed_for_model(Workshop, time_scope), :view_count)
      @most_viewed_workshop_variations = decorate_with_counts(most_viewed_for_model(WorkshopVariation, time_scope), :view_count)
      @most_viewed_resources = decorate_with_counts(most_viewed_for_model(Resource, time_scope), :view_count)
      @most_viewed_community_news = decorate_with_counts(most_viewed_for_model(CommunityNews, time_scope), :view_count)
      @most_viewed_stories = decorate_with_counts(most_viewed_for_model(Story, time_scope), :view_count)
      @most_viewed_quotes = decorate_with_counts(most_viewed_for_model(Quote, time_scope), :view_count)
      @most_viewed_tutorials = decorate_with_counts(most_viewed_for_model(Tutorial, time_scope), :view_count)
      @most_viewed_projects = decorate_with_counts(most_viewed_for_model(Project, time_scope), :view_count)
      @most_viewed_events = decorate_with_counts(most_viewed_for_model(Event, time_scope), :view_count)
      @most_viewed_facilitators = decorate_with_counts(most_viewed_for_model(Facilitator, time_scope), :view_count)

      @most_printed_workshops = decorate_with_counts(most_printed_for_model(Workshop, time_scope), :print_count)
      @most_downloaded_resources = decorate_with_counts(most_downloaded_for_model(Resource, time_scope), :download_count)

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

    private

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
      counts_by_id = resource_ids_with_counts.to_h { |id, count| [ id.to_i, count ] }
      # Sort records to match the order from the view counts and attach view_count
      id_positions = record_ids.each_with_index.to_h
      records.sort_by { |record| id_positions[record.id] || Float::INFINITY }.map do |record|
        # Store the count before decoration
        count = counts_by_id[record.id]
        record.instance_variable_set(:@view_count, count)
        record.define_singleton_method(:view_count) { @view_count }
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
      counts_by_id = resource_ids_with_counts.to_h { |id, count| [ id.to_i, count ] }
      # Sort records to match the order from the print counts and attach print_count
      id_positions = record_ids.each_with_index.to_h
      records.sort_by { |record| id_positions[record.id] || Float::INFINITY }.map do |record|
        # Store the count before decoration
        count = counts_by_id[record.id]
        record.instance_variable_set(:@print_count, count)
        record.define_singleton_method(:print_count) { @print_count }
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
      counts_by_id = resource_ids_with_counts.to_h { |id, count| [ id.to_i, count ] }
      # Sort records to match the order from the download counts and attach download_count
      id_positions = record_ids.each_with_index.to_h
      records.sort_by { |record| id_positions[record.id] || Float::INFINITY }.map do |record|
        # Store the count before decoration
        count = counts_by_id[record.id]
        record.instance_variable_set(:@download_count, count)
        record.define_singleton_method(:download_count) { @download_count }
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
