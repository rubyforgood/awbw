module TaggingsHelper
  def tagged_index_path(type, sector_names_all:, category_names_all:)
    klass = Tag::TAGGABLE_META.fetch(type)[:klass]

    params = { published: true }

    if sector_names_all.present?
      params[:sector_names_all] = sector_names_all
    end

    if category_names_all.present?
      params[:category_names_all] = category_names_all
    end

    polymorphic_path(klass, params)
  end
end
