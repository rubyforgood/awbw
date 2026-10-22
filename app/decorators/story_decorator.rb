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

  def workshop_links(link_class: "hover:underline")
    return direct_workshop_links(link_class) if story_workshops.empty?
    parts = story_workshops.map { |sw| workshop_reference_link(sw, link_class) }.compact
    h.safe_join(parts, " / ") if parts.any?
  end

  def organization_link(link_class: "hover:underline")
    return if organization.nil?
    return organization.name unless h.allowed_to?(:show?, organization)
    h.link_to(organization.name, h.organization_path(organization), class: link_class, data: { turbo_frame: "_top" })
  end

  def showcase_path
    h.allowed_to?(:show?, object, with: StorySharePolicy) ? h.story_share_path(object) : h.story_path(object)
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

  def direct_workshop_links(link_class)
    parts = [
      (workshop_link(workshop, link_class) if workshop),
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

  def workshop_reference_link(story_workshop, link_class)
    workshop = story_workshop.workshop
    text = story_workshop.external_workshop_title.presence || workshop&.title
    return h.html_escape(text) if workshop.nil?

    workshop_link(workshop, link_class, text:)
  end

  def workshop_link(workshop, link_class, text: workshop.title)
    return h.html_escape(text) unless h.allowed_to?(:show?, workshop)
    h.link_to(text, h.workshop_path(workshop), class: link_class, data: { turbo_frame: "_top" })
  end
end
