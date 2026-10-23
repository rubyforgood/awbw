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
    primary = primary_sector
    viewable_tags(sectorable_items.map(&:sector)).sort_by { |sector| [ sector == primary ? 0 : 1, sector.name.downcase ] }
  end

  def tag_audience_categories
    primary = primary_category
    audiences = categorizable_items.map(&:category).select { |category| category&.category_type&.name.in?(CategoriesTaggable::AUDIENCE_CATEGORY_TYPES) }
    viewable_tags(audiences).sort_by { |category| [ category == primary ? 0 : 1, category.name.downcase ] }
  end

  def windows_audience_chip
    return unless windows_type && h.current_user&.super_user?

    h.tag.span(class: "admin-only inline-flex items-center gap-1 rounded-md border border-blue-200 bg-blue-100 px-2 py-0.5 text-xs font-medium text-blue-900",
               title: "Windows audience (admin only)") do
      h.safe_join([ h.tag.i(class: "fa-solid fa-lock text-2xs text-blue-700", aria: { hidden: true }), windows_type.short_name ])
    end
  end

  def showcase_path(**params)
    h.allowed_to?(:show?, object, with: StorySharePolicy) ? h.story_share_path(object, **params) : h.story_path(object)
  end

  private

  def viewable_tags(tags)
    tags = tags.compact
    h.current_user&.super_user? ? tags : tags.select(&:published?)
  end

  def workshop_references
    story_workshops
  end
end
