class StoryIdeaDecorator < ApplicationDecorator
  def title
    name
  end

  def detail(length: 100)
    text = rhino_body&.to_plain_text
    length ? text&.truncate(length) : text
  end

  def workshop_links
    return direct_workshop_links if story_idea_workshops.empty?
    parts = story_idea_workshops.map { |siw| workshop_reference_link(siw) }.compact
    h.safe_join(parts, " / ") if parts.any?
  end

  def workshop_reference_count
    return story_idea_workshops.size if story_idea_workshops.any?
    [ workshop, external_workshop_title.presence ].compact.size
  end

  # Read-only display of the legacy single-workshop columns kept as a safety net
  # during the join-table migration; the form surfaces it so nothing silently hides.
  def legacy_workshop_reference
    [ workshop&.title, external_workshop_title.presence ].compact_blank.presence&.join(" / ")
  end

  private

  def direct_workshop_links
    parts = [
      (h.link_to(workshop.title, h.workshop_path(workshop), class: "hover:underline") if workshop),
      (h.html_escape(external_workshop_title) if external_workshop_title.presence)
    ].compact
    h.safe_join(parts, " / ") if parts.any?
  end

  def workshop_reference_link(story_idea_workshop)
    workshop = story_idea_workshop.workshop
    external_title = story_idea_workshop.external_workshop_title.presence
    return h.html_escape(external_title) if workshop.nil?

    link = h.link_to(workshop.title, h.workshop_path(workshop), class: "hover:underline")
    return link unless external_title
    h.safe_join([ external_title, " (from the ", link, ")" ])
  end
end
