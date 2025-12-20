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
		quotes:         :slate,
		tags:           :lime
	}

	def self.color_for(key)
		TAGGABLE_COLORS[key.to_sym]
	end

	def self.bg_class_for(key, intensity: 50)
		color = color_for(key)
		color ? "bg-#{color}-#{intensity}" : "bg-gray-50"
	end

	def self.text_class_for(key, intensity: 700)
		color = color_for(key)
		color ? "text-#{color}-#{intensity}" : "text-gray-700"
	end
end