module Admin
  class AnalyticsController < Admin::BaseController
    protect_from_forgery with: :null_session

    def index
      time_scope = apply_time_filter(params[:time_period])

      @most_viewed_workshops    = time_scope.call(Workshop.published).order(view_count: :desc, created_at: :desc).limit(10).decorate
      @most_viewed_workshop_variations = time_scope.call(WorkshopVariation.published).order(view_count: :desc, created_at: :desc).limit(10).decorate
      @most_viewed_resources    = time_scope.call(Resource.published).order(view_count: :desc, created_at: :desc).limit(10).decorate
      @most_viewed_community_news = time_scope.call(CommunityNews.published).order(view_count: :desc, created_at: :desc).limit(10).decorate
      @most_viewed_stories      = time_scope.call(Story.published).order(view_count: :desc, created_at: :desc).limit(10).decorate
      @most_viewed_quotes       = time_scope.call(Quote.published).order(view_count: :desc, created_at: :desc).limit(10).decorate
      @most_viewed_tutorials    = time_scope.call(Tutorial.published).order(view_count: :desc, created_at: :desc).limit(10).decorate
      @most_viewed_projects     = time_scope.call(Project.published).order(view_count: :desc, created_at: :desc).limit(10).decorate
      @most_viewed_events       = time_scope.call(Event.published).order(view_count: :desc, created_at: :desc).limit(10).decorate
      @most_viewed_facilitators = time_scope.call(Facilitator.published).order(view_count: :desc, created_at: :desc).limit(10).decorate

      @most_printed_workshops = time_scope.call(Workshop.published).order(print_count: :desc, created_at: :desc).limit(10).decorate
      @most_downloaded_resources = time_scope.call(Resource.published).order(download_count: :desc, created_at: :desc).limit(10).decorate

      @zero_engagement_workshops = time_scope.call(Workshop.published).where(view_count: 0).order(created_at: :desc).limit(10).decorate
      @zero_engagement_resources = time_scope.call(Resource.published).where(view_count: 0).order(created_at: :desc).limit(10).decorate

      @summary = {
        workshops: time_scope.call(Workshop).sum(:view_count),
        workshop_prints: time_scope.call(Workshop).sum(:print_count),
        resources: time_scope.call(Resource).sum(:view_count),
        resource_downloads: time_scope.call(Resource).sum(:download_count),
        community_news: time_scope.call(CommunityNews).sum(:view_count),
        stories: time_scope.call(Story).sum(:view_count),
        events: time_scope.call(Event).sum(:view_count),
        workshop_variations: time_scope.call(WorkshopVariation).sum(:view_count),
        quotes: time_scope.call(Quote).sum(:view_count),
        tutorials: time_scope.call(Tutorial).sum(:view_count),
        projects: time_scope.call(Project).sum(:view_count),
        facilitators: time_scope.call(Facilitator).sum(:view_count)
      }
    end

    private

    def apply_time_filter(time_period)
      case time_period
      when 'past_week'
        ->(scope) { scope.where('created_at >= ?', 1.week.ago) }
      when 'past_month'
        ->(scope) { scope.where('created_at >= ?', 1.month.ago) }
      when 'past_year'
        ->(scope) { scope.where('created_at >= ?', 1.year.ago) }
      else # 'all_time' or nil
        ->(scope) { scope }
      end
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
