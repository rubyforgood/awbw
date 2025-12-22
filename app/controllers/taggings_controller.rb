class TaggingsController < ApplicationController
	def index
		@sector_names = params[:sector_names].to_s
		@category_names = params[:category_names].to_s

		number_of_items_per_page = params[:number_of_items_per_page].present? ? params[:number_of_items_per_page].to_i : 9
		pages = {
			workshops: params[:workshops_page],
			resources: params[:resources_page],
			stories: params[:stories_page],
			community_news: params[:community_news_page],
			events: params[:events_page],
			facilitators: params[:facilitators_page],
			projects: params[:projects_page],
			quotes: params[:quotes_page]
		}

		@grouped_tagged_items = TaggingSearchService.call(sector_names: @sector_names,
																											category_names: @category_names,
																											pages: pages,
																											number_of_items_per_page: number_of_items_per_page)
	end

	def matrix
		@sectors =
			Sector
				.joins(:sectorable_items)
				.published
				.distinct
				.order(:name)

		@categories =
			Category
				.joins(:category_type, :categorizable_items)
				.published
				.select("categories.*, metadata.name AS category_type_name")
				.distinct
				.order("category_type_name ASC, categories.name ASC")



		# ------------------------------------------------------------------
		# 1. Build raw counts (SOURCE OF TRUTH)
		# ------------------------------------------------------------------
		@model_heatmap_stats = {}

		Tag::TAGGABLE_META.each do |key, data|
			klass = data[:klass]
			@model_heatmap_stats[key] = { sector: {}, category: {} }

			klass
				.published
				.joins(:sectors)
				.group("sectors.id")
				.count
				.each do |sector_id, count|
				@model_heatmap_stats[key][:sector][sector_id] = count
			end

			klass
				.published
				.joins(:categories)
				.group("categories.id")
				.count
				.each do |category_id, count|
				@model_heatmap_stats[key][:category][category_id] = count
			end
		end

		# ------------------------------------------------------------------
		# 2. Compute quantiles FROM counts
		# ------------------------------------------------------------------
		@model_heatmap_quantiles = {}

		@model_heatmap_stats.each do |key, dimensions|
			@model_heatmap_quantiles[key] = {}

			dimensions.each do |type, counts|
				values = counts.values.sort
				next if values.empty?

				@model_heatmap_quantiles[key][type] = {
					q20: values[(values.length * 0.2).floor],
					q40: values[(values.length * 0.4).floor],
					q60: values[(values.length * 0.6).floor],
					q80: values[(values.length * 0.8).floor]
				}
			end
		end
	end

end