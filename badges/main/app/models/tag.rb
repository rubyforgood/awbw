class Tag
	TAGGABLE_META = {
		workshops: {
			icon: "🎨",
			path: -> { Rails.application.routes.url_helpers.workshops_path },
			klass: Workshop
		},
		resources: {
			icon: "📚",
			path: -> { Rails.application.routes.url_helpers.resources_path },
			klass: Resource
		},
		community_news: {
			icon: "📰",
			path: -> { Rails.application.routes.url_helpers.community_news_index_path },
			klass: CommunityNews
		},
		stories: {
			icon: "🗣️",
			path: -> { Rails.application.routes.url_helpers.stories_path },
			klass:  Story
		},
		events: {
			icon: "📆",
			path: -> { Rails.application.routes.url_helpers.events_path },
			klass: Event
		},
		facilitators: {
			icon: "🧑‍🎨",
			path: -> { Rails.application.routes.url_helpers.facilitators_path },
			klass: Facilitator
		},
		projects: {
			icon: "🏫",
			path: -> { Rails.application.routes.url_helpers.projects_path },
			klass: ::Project
		},
		quotes: {
			icon: "💬",
			path: -> { Rails.application.routes.url_helpers.quotes_path },
			klass: Quote
		}
	}.freeze

	def self.dashboard_card_for(key)
		meta = TAGGABLE_META.fetch(key)

		{
			title: key.to_s.humanize,
			path: meta[:path].call,
			icon: meta[:icon],
			bg_color: DomainTheme.bg_class_for(key),
			hover_bg_color: DomainTheme.bg_class_for(key, intensity: 100),
			text_color: "text-gray-800"
		}
	end

end