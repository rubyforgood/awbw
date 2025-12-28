module Admin
	class AnalyticsController < Admin::BaseController
		protect_from_forgery with: :null_session

		def index
			@most_viewed_workshops    = Workshop.published.order(view_count: :desc, created_at: :desc).limit(10).decorate
			@most_viewed_workshop_variations = WorkshopVariation.published.order(view_count: :desc, created_at: :desc).limit(10).decorate
			@most_viewed_resources    = Resource.published.order(view_count: :desc, created_at: :desc).limit(10).decorate
			@most_viewed_community_news = CommunityNews.published.order(view_count: :desc, created_at: :desc).limit(10).decorate
			@most_viewed_stories      = Story.published.order(view_count: :desc, created_at: :desc).limit(10).decorate
			@most_viewed_quotes       = Quote.published.order(view_count: :desc, created_at: :desc).limit(10).decorate
			@most_viewed_tutorials    = Tutorial.published.order(view_count: :desc, created_at: :desc).limit(10).decorate
			@most_viewed_projects     = Project.published.order(view_count: :desc, created_at: :desc).limit(10).decorate
			@most_viewed_events       = Event.published.order(view_count: :desc, created_at: :desc).limit(10).decorate
			@most_viewed_facilitators = Facilitator.published.order(view_count: :desc, created_at: :desc).limit(10).decorate

			@most_printed_workshops = Workshop.published.order(print_count: :desc, created_at: :desc).limit(10).decorate
			@most_downloaded_resources = Resource.published.order(download_count: :desc, created_at: :desc).limit(10).decorate

			@zero_engagement_workshops = Workshop.published.where(view_count: 0).order(created_at: :desc).limit(10).decorate
			@zero_engagement_resources = Resource.published.where(view_count: 0).order(created_at: :desc).limit(10).decorate

			@summary = {
				workshops: Workshop.sum(:view_count),
				workshop_prints: Workshop.sum(:print_count),
				resources: Resource.sum(:view_count),
				resource_downloads: Resource.sum(:download_count),
				community_news: CommunityNews.sum(:view_count),
				stories: Story.sum(:view_count),
				events: Event.sum(:view_count),
				workshop_variations: WorkshopVariation.sum(:view_count),
				quotes: Quote.sum(:view_count),
				tutorials: Tutorial.sum(:view_count),
				projects: Project.sum(:view_count),
				facilitators: Facilitator.sum(:view_count)
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

			record.increment_print_count!

			head :ok
		end
	end

end
