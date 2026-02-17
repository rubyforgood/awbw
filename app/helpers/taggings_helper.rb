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

  # Collects all tags (sectors and categories) for a resource
  # Returns an array of tag names sorted appropriately
  def collect_all_tags(resource)
    all_tags = []

    if resource.respond_to?(:sectors) && resource.sectors.any?
      all_tags += resource.sectors
        .sort_by { |s| s.name.to_s.downcase }
        .map(&:name)
    end

    if resource.respond_to?(:categories) && resource.categories.any?
      all_tags += resource.categories
        .sort_by { |c| [ c.position.to_i, c.name.to_s.downcase ] }
        .map(&:name)
    end

    all_tags
  end
end
