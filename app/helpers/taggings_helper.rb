module TaggingsHelper
  def tagged_index_path(type, sector_names:, category_names:)
    klass = Tag::TAGGABLE_META.fetch(type)[:klass]

    params = { published: true }

    if sector_names.present?
      params[:sector_names] = sector_names
    end

    if category_names.present?
      params[:category_names] = category_names
    end

    polymorphic_path(klass, params)
  end
end
