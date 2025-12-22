module TagMatrixHelper

	def tag_count_for(model, tag:, type:)
		scope =
			case type
			when :sector
				model.sector_names(tag.name)
			when :category
				model.category_names(tag.name)
			end

		scope.published.count
	end

	def tag_link_for(model, tag:, type:)
		params =
			case type
			when :sector
				{ sector_names: tag.name, published: true }
			when :category
				{ category_names: tag.name, published: true }
			end

		polymorphic_path(model, params)
	end

	def heatmap_class_for(count, model_key:, type:, quantiles:)
		return "bg-white" if count.zero?

		q = quantiles.dig(model_key, type)
		shade =
			if q.nil?
				200
			elsif count <= q[:q20] then 50
			elsif count <= q[:q40] then 100
			elsif count <= q[:q60] then 200
			elsif count <= q[:q80] then 300
			else 400
			end

		base_color = DomainTheme::COLORS[model_key] || :gray
		"bg-#{base_color}-#{shade}"
	end

end
