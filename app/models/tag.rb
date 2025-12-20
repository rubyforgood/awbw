class Tag
	TAGGABLE_MODELS = {
		workshops:      Workshop,
		resources:      Resource,
		community_news: CommunityNews,
		stories:        Story,
		events:         Event,
		facilitators:   Facilitator,
		projects:       ::Project,
		quotes:         Quote
	}

	TAGGABLE_COLORS = {
		workshops:      :indigo,
		workshops_variations: :purple,
		workshop_logs: :teal,
		resources:      :violet,
		community_news: :orange,
		stories:        :rose,
		events:         :blue,
		facilitators:   :sky,
		projects:       :emerald,
		quotes:         :slate
	}
end