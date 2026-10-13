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
    return direct_workshop_title if story_workshops.empty?
    story_workshops.map { |sw| workshop_reference_label(sw) }.compact_blank.presence&.join(" / ")
  end

  def workshop_links
    return direct_workshop_links if story_workshops.empty?
    parts = story_workshops.map { |sw| workshop_reference_link(sw) }.compact
    h.safe_join(parts, " / ") if parts.any?
  end

  def workshop_reference_count
    return story_workshops.size if story_workshops.any?
    [ workshop, external_workshop_title.presence ].compact.size
  end

  # Read-only display of the legacy single-workshop columns kept as a safety net
  # during the join-table migration; the form surfaces it so nothing silently hides.
  def legacy_workshop_reference
    direct_workshop_title
  end

  private

  def direct_workshop_title
    [ workshop&.title, external_workshop_title.presence ].compact_blank.presence&.join(" / ")
  end

  def direct_workshop_links
    parts = [
      (h.link_to(workshop.title, h.workshop_path(workshop), class: "hover:underline") if workshop),
      (h.html_escape(external_workshop_title) if external_workshop_title.presence)
    ].compact
    h.safe_join(parts, " / ") if parts.any?
  end

  def workshop_reference_label(story_workshop)
    workshop_title = story_workshop.workshop&.title
    external_title = story_workshop.external_workshop_title.presence
    return "#{external_title} (from the #{workshop_title})" if external_title && workshop_title
    external_title || workshop_title
  end

  def workshop_reference_link(story_workshop)
    workshop = story_workshop.workshop
    external_title = story_workshop.external_workshop_title.presence
    return h.html_escape(external_title) if workshop.nil?

    link = h.link_to(workshop.title, h.workshop_path(workshop), class: "hover:underline")
    return link unless external_title
    h.safe_join([ external_title, " (from the ", link, ")" ])
  end
end
