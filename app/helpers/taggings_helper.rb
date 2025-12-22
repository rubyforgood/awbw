module TaggingsHelper

	def tagged_index_path(type, sector_names:, category_names:)
		klass = Tag::TAGGABLE_META.fetch(type)[:klass]

		params = {}

		if sector_names.present?
			sector_ids = Sector.names(sector_names).published.pluck(:id)
			params[:sectors] = hashify_ids(sector_ids)
		end

		if category_names.present?
			category_ids = Category.names(category_names).published.pluck(:id)
			params[:categories] = hashify_ids(category_ids)
		end

		polymorphic_path(klass, params)
	end

	private

	def hashify_ids(ids)
		ids.index_with(&:to_i)
	end
end
