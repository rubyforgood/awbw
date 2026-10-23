class StoryDecorator < ApplicationDecorator
  include ::Linkable

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

  def workshop_links(link_class: "hover:underline")
    parts = story_workshops.map { |sw| workshop_reference_link(sw, link_class) }.compact
    h.safe_join(parts, " / ") if parts.any?
  end

  def workshop_label
    "Workshop".pluralize(story_workshops.size)
  end

  def facilitator_spotlight?
    spotlighted_facilitator_id.present?
  end

  private

  def workshop_reference_label(story_workshop)
    workshop_title = story_workshop.workshop&.title
    external_title = story_workshop.external_workshop_title.presence
    return "#{external_title} (from the #{workshop_title})" if external_title && workshop_title
    external_title || workshop_title
  end

  def workshop_reference_link(story_workshop, link_class)
    workshop = story_workshop.workshop
    return h.html_escape(workshop_reference_label(story_workshop)) unless workshop && h.allowed_to?(:show?, workshop)

    external_title = story_workshop.external_workshop_title.presence
    link = h.link_to(workshop.title, h.workshop_path(workshop), class: link_class, data: { turbo_frame: "_top" })
    return link unless external_title
    h.safe_join([ external_title, " (from the ", link, ")" ])
  end
end
