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

		q = quantiles[model_key][type]
		return base_color(model_key, 200) if q.nil?

		shade =
			if count <= q[:q20]
				50
			elsif count <= q[:q40]
				100
			elsif count <= q[:q60]
				200
			elsif count <= q[:q80]
				300
			else
				400
			end

		base_color(model_key, shade)
	end

	def base_color(model_key, shade)
		color = Tag::TAGGABLE_COLORS.fetch(model_key, :gray)
		{
			indigo:  {
				50 => "bg-indigo-50", 100 => "bg-indigo-100",
				200 => "bg-indigo-200", 300 => "bg-indigo-300", 400 => "bg-indigo-400"
			},
			violet: {
				50 => "bg-violet-50", 100 => "bg-violet-100",
				200 => "bg-violet-200", 300 => "bg-violet-300", 400 => "bg-violet-400"
			},
			orange: {
				50 => "bg-orange-50", 100 => "bg-orange-100",
				200 => "bg-orange-200", 300 => "bg-orange-300", 400 => "bg-orange-400"
			},
			rose: {
				50 => "bg-rose-50", 100 => "bg-rose-100",
				200 => "bg-rose-200", 300 => "bg-rose-300", 400 => "bg-rose-400"
			},
			blue: {
				50 => "bg-blue-50", 100 => "bg-blue-100",
				200 => "bg-blue-200", 300 => "bg-blue-300", 400 => "bg-blue-400"
			},
			sky: {
				50 => "bg-sky-50", 100 => "bg-sky-100",
				200 => "bg-sky-200", 300 => "bg-sky-300", 400 => "bg-sky-400"
			},
			cyan: {
				50 => "bg-cyan-50", 100 => "bg-cyan-100",
				200 => "bg-cyan-200", 300 => "bg-cyan-300", 400 => "bg-cyan-400"
			},
			emerald: {
				50 => "bg-emerald-50", 100 => "bg-emerald-100",
				200 => "bg-emerald-200", 300 => "bg-emerald-300", 400 => "bg-emerald-400"
			},
			gray: {
				50 => "bg-gray-50", 100 => "bg-gray-100",
				200 => "bg-gray-200", 300 => "bg-gray-300", 400 => "bg-gray-400"
			}
		}.dig(color, shade) || "bg-gray-100"
	end
end
