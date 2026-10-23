class StoryIdeaDecorator < ApplicationDecorator
  include ::StoryReferenceLinks

  def title
    name
  end

  def detail(length: 100)
    text = rhino_body&.to_plain_text
    length ? text&.truncate(length) : text
  end

  # Read-only display of the legacy single-workshop columns kept as a safety net
  # during the join-table migration; the form surfaces it so nothing silently hides.
  def legacy_workshop_reference
    [ workshop&.title, external_workshop_title.presence ].compact_blank.presence&.join(" / ")
  end

  private

  def workshop_references
    story_idea_workshops
  end
end
