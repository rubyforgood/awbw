class TagsController < ApplicationController
	def index
		@sectors =
			Sector
				.joins(:sectorable_items)
				.published
				.distinct
				.order(:name)

		categories =
			Category
				.joins(:category_type, :categorizable_items)
				.published
				.select("categories.*, metadata.name AS category_type_name")
				.distinct
				.order("category_type_name ASC, categories.name ASC")

		@categories_by_type = categories.group_by(&:category_type_name)
	end

end
