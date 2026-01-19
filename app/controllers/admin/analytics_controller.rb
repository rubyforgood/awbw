module Admin
  class AnalyticsController < Admin::BaseController
    protect_from_forgery with: :null_session

    def index
      time_scope = apply_time_filter(params[:time_period])

      # Query Ahoy events for view counts within the time period
      @most_viewed_workshops = most_viewed_for_model(Workshop, time_scope).limit(10).decorate
      @most_viewed_workshop_variations = most_viewed_for_model(WorkshopVariation, time_scope).limit(10).decorate
      @most_viewed_resources = most_viewed_for_model(Resource, time_scope).limit(10).decorate
      @most_viewed_community_news = most_viewed_for_model(CommunityNews, time_scope).limit(10).decorate
      @most_viewed_stories = most_viewed_for_model(Story, time_scope).limit(10).decorate
      @most_viewed_quotes = most_viewed_for_model(Quote, time_scope).limit(10).decorate
      @most_viewed_tutorials = most_viewed_for_model(Tutorial, time_scope).limit(10).decorate
      @most_viewed_projects = most_viewed_for_model(Project, time_scope).limit(10).decorate
      @most_viewed_events = most_viewed_for_model(Event, time_scope).limit(10).decorate
      @most_viewed_facilitators = most_viewed_for_model(Facilitator, time_scope).limit(10).decorate

      @most_printed_workshops = time_scope.call(Workshop.published).order(print_count: :desc, created_at: :desc).limit(10).decorate
      @most_downloaded_resources = time_scope.call(Resource.published).order(download_count: :desc, created_at: :desc).limit(10).decorate

      @zero_engagement_workshops = zero_engagement_for_model(Workshop, time_scope).limit(10).decorate
      @zero_engagement_resources = zero_engagement_for_model(Resource, time_scope).limit(10).decorate

      @summary = {
        workshops: view_count_for_model(Workshop, time_scope),
        workshop_prints: time_scope.call(Workshop).sum(:print_count),
        resources: view_count_for_model(Resource, time_scope),
        resource_downloads: time_scope.call(Resource).sum(:download_count),
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
      case time_period
      when 'past_week'
        ->(scope) { 
          # For Ahoy::Event, filter by time column; for other models, use created_at
          if scope.respond_to?(:klass) && scope.klass == Ahoy::Event
            scope.where('time >= ?', 1.week.ago)
          else
            scope.where('created_at >= ?', 1.week.ago)
          end
        }
      when 'past_month'
        ->(scope) { 
          if scope.respond_to?(:klass) && scope.klass == Ahoy::Event
            scope.where('time >= ?', 1.month.ago)
          else
            scope.where('created_at >= ?', 1.month.ago)
          end
        }
      when 'past_year'
        ->(scope) { 
          if scope.respond_to?(:klass) && scope.klass == Ahoy::Event
            scope.where('time >= ?', 1.year.ago)
          else
            scope.where('created_at >= ?', 1.year.ago)
          end
        }
      else # 'all_time' or nil
        ->(scope) { scope }
      end
    end

    def most_viewed_for_model(model_class, time_scope)
      model_name = model_class.name
      event_name = "#{model_name} View"
      
      # Get resource IDs with their view counts from Ahoy events
      resource_ids_with_counts = Ahoy::Event
        .where(name: event_name)
        .then { |query| time_scope.call(query) }
        .group("properties->>'$.resource_id'")
        .count
        .sort_by { |_id, count| -count }
        .first(10)
        .map { |id, _count| id.to_i }

      # Fetch the actual records in the same order
      records = model_class.published.where(id: resource_ids_with_counts)
      
      # Sort records to match the order from the view counts
      records.sort_by { |record| resource_ids_with_counts.index(record.id) || Float::INFINITY }
    end

    def zero_engagement_for_model(model_class, time_scope)
      model_name = model_class.name
      event_name = "#{model_name} View"
      
      # Get IDs of resources that have been viewed in the time period
      viewed_ids = Ahoy::Event
        .where(name: event_name)
        .then { |query| time_scope.call(query) }
        .distinct
        .pluck("properties->>'$.resource_id'")
        .map(&:to_i)

      # Get resources created in time period that haven't been viewed
      time_scope.call(model_class.published)
        .where.not(id: viewed_ids)
        .order(created_at: :desc)
    end

    def view_count_for_model(model_class, time_scope)
      model_name = model_class.name
      event_name = "#{model_name} View"
      
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

      record.increment_print_count!

      head :ok
    end
  end
end
