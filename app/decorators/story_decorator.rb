class StoryDecorator < ApplicationDecorator
  include ::Linkable
  include ::StoryReferenceLinks

  def detail(length: 50)
    text = rhino_body&.to_plain_text
    length ? text&.truncate(length) : text
  end

  def external_url
    object.website_url
  end

  def workshop_title
    story_workshops.map { |sw| workshop_reference_label(sw) }.compact_blank.presence&.join(" / ")
  end

  def spotlighted_facilitator_label
    return unless spotlighted_facilitator

    [ "Spotlighted facilitator", spotlighted_facilitator.name.presence ].compact.join(": ")
  end

  def spotlighted_facilitator_link(link_class: "hover:underline")
    person = spotlighted_facilitator
    return if person.nil?
    return person.name unless h.allowed_to?(:show?, person)
    h.link_to(person.name, h.person_path(person), class: link_class, data: { turbo_frame: "_top" })
  end

  def tag_sectors
    @tag_sectors ||= begin
      primary = primary_sector
      viewable_tags(sectorable_items.map(&:sector)).sort_by { |sector| [ sector == primary ? 0 : 1, sector.name.downcase ] }
    end
  end

  def tag_audience_categories
    @tag_audience_categories ||= begin
      primary = primary_category
      audiences = categorizable_items.map(&:category).select { |category| category&.category_type&.name.in?(CategoriesTaggable::AUDIENCE_CATEGORY_TYPES) }
      viewable_tags(audiences).sort_by { |category| [ category == primary ? 0 : 1, category.name.downcase ] }
    end
  end

  # Each group's lead tag (its primary, else the first alphabetically) shows as a chip; the rest collapse into "+N more".
  def lead_tag_sector = tag_sectors.first

  def lead_tag_audience_category = tag_audience_categories.first

  def more_tag_links(link_class: "hover:underline")
    sector_links = tag_sectors.drop(1).map { |sector| tag_page_link(sector.name, { sector_names_all: sector.name }, link_class) }
    audience_links = tag_audience_categories.drop(1).map { |category| tag_page_link(category.name, { category_names_all: category.name }, link_class) }
    sector_links + audience_links
  end

  def windows_audience_chip
    return unless windows_type && h.allowed_to?(:manage?, Story)

    h.tag.span(class: "admin-only inline-flex items-center gap-1 rounded-md border border-blue-200 bg-blue-100 px-2 py-0.5 text-xs font-medium text-blue-900",
               title: "Windows audience (admin only)") do
      h.safe_join([ h.tag.i(class: "fa-solid fa-lock text-2xs text-blue-700", aria: { hidden: true }), windows_type.short_name ])
    end
  end

  def showcase_path(**params)
    h.allowed_to?(:show?, object, with: StorySharePolicy) ? h.story_share_path(object, **params) : h.story_path(object)
  end

  private

  def tag_page_link(name, params, link_class)
    h.link_to(name, h.taggings_path(params), class: link_class, data: { turbo_frame: "_top" })
  end

  def viewable_tags(tags)
    tags = tags.compact
    h.allowed_to?(:manage?, Story) ? tags : tags.select(&:published?)
  end

  def workshop_references
    story_workshops
  end
end
