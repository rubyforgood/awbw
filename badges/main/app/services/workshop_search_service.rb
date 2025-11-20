class WorkshopSearchService
	attr_reader :params, :super_user
	attr_accessor :workshops, :sort

	def initialize(params = {}, super_user: false)
		@params = params
		@super_user = super_user
		@workshops = Workshop.all
		@sort = default_sort
	end

	# Main entry point
	def call
		filter_by_params
		order_by_params
		resolve_ids_order
		self # <- returns the WorkshopSearchService instance itself
	end

	# Compute the effective sort
	def default_sort
		params[:sort].presence || 'title'
		# return params[:sort] if params[:sort].present?
		# return 'keywords' if params[:query].present? # only when returning weighted results from # search_by_query
		# 'title'
	end

	private

	# --- Filtering ---

	def filter_by_params
		filter_by_windows_type
		filter_by_published_status
		filter_by_title
		filter_by_query
		filter_by_author_name
		filter_by_categories
		filter_by_sectors
	end

	def filter_by_windows_type
		return unless params[:windows_types].present?
		ids = params[:windows_types].values.map(&:to_i)
		@workshops = @workshops.windows_type_ids(ids)
	end

	def filter_by_published_status
		if super_user
			active   = ActiveModel::Type::Boolean.new.cast(params[:active])   if params.key?(:active)
			inactive = ActiveModel::Type::Boolean.new.cast(params[:inactive]) if params.key?(:inactive)

			@workshops =
				if active && !inactive
					@workshops.published(true)
				elsif inactive && !active
					@workshops.published(false)
				else
					@workshops
				end
		else
			@workshops = @workshops.published
		end
	end

	def filter_by_author_name
		return unless params[:author_name].present?
		@workshops = search_by_author_name(@workshops, params[:author_name])
	end

	def filter_by_categories
		return unless params[:categories].present?
		@workshops = search_by_categories(@workshops, params[:categories])
	end

	def filter_by_sectors
		return unless params[:sectors].present?
		@workshops = search_by_sectors(@workshops, params[:sectors])
	end

	def filter_by_title
		return unless params[:title].present?
		@workshops = @workshops.title(params[:title])
	end

	def filter_by_query
		return unless params[:query].present?

		results = @workshops.search(params[:query]) # Use the SearchCop search scope directly on the relation

		# If SearchCop returned an Array (e.g., because of scoring), convert back to Relation
		if results.is_a?(Array)
			ordered_ids = results.map(&:id)
			@workshops = Workshop.where(id: ordered_ids)
													 .order(Arel.sql("FIELD(id, #{ordered_ids.join(',')})"))
		else
			@workshops = results
		end
	end

	# --- Search methods ---

	def search_by_author_name(workshops, author_name)
		return workshops if author_name.blank?

		sanitized = author_name.strip.gsub(/\s+/, '')
		workshops.left_outer_joins(:user)
						 .where(
							 "LOWER(REPLACE(workshops.full_name, ' ', '')) LIKE :name
                OR LOWER(REPLACE(CONCAT(users.first_name, users.last_name), ' ', '')) LIKE :name
                OR LOWER(REPLACE(CONCAT(users.last_name, users.first_name), ' ', '')) LIKE :name
                OR LOWER(REPLACE(users.first_name, ' ', '')) LIKE :name
                OR LOWER(REPLACE(users.last_name, ' ', '')) LIKE :name",
							 name: "%#{sanitized}%"
						 )
	end

	def search_by_categories(workshops, categories)
		ids = categories.to_unsafe_h.values.reject(&:blank?)
		return workshops if ids.empty?
		workshops.joins(:categorizable_items)
						 .where(categorizable_items: { categorizable_type: "Workshop", category_id: ids })
						 .distinct
	end

	def search_by_sectors(workshops, sectors)
		ids = sectors.to_unsafe_h.values.reject(&:blank?)
		return workshops if ids.empty?
		workshops.joins(:sectorable_items)
						 .where(sectorable_items: { sectorable_type: "Workshop", sector_id: ids })
						 .distinct
	end

	# --- Sorting ---

	def order_by_params
		case sort
		when 'created'
			# order by year/month desc, then created_at desc, then title asc
			@workshops = @workshops.order(
				Arel.sql(<<~SQL.squish)
          CASE WHEN year IS NOT NULL AND month IS NOT NULL THEN 1 ELSE 2 END ASC,
          year DESC,
          month DESC,
          created_at DESC,
          title ASC
        SQL
			)
		when 'led'
			@workshops = @workshops.order(led_count: :desc, title: :asc)
		when 'title'
			@workshops = @workshops.order(title: :asc)
		when 'keywords'
			# already ordered in filter_by_query
		else
			@workshops = @workshops.order(title: :asc)
		end
	end

	# --- Handle distinct + order by FIELD(id, ...) for complex joins ---
	def resolve_ids_order
		return if sort == 'keywords' # ordering is already handled if this is the case

		# Determine sort columns for select
		sort_columns = case sort
									 when 'created' then [:id, :created_at, :year, :month, :title]
									 when 'led'     then [:id, :led_count, :title]
									 when 'title'   then [:id, :title]
									 else [:id, :title]
									 end

    workshop_ids = @workshops
      .select(*sort_columns)
      .order(sort_columns)
      .map(&:id)
		@workshops = Workshop.where(id: workshop_ids)
												 .order(Arel.sql("FIELD(id, #{workshop_ids.join(',')})"))
	end
end
