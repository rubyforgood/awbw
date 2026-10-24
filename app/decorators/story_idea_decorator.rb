class StoryIdeaDecorator < ApplicationDecorator
  include ::StoryReferenceLinks

  def title
    name
  end

  def detail(length: 100)
    text = rhino_body&.to_plain_text
    length ? text&.truncate(length) : text
  end

  private

  def workshop_references
    story_idea_workshops
  end
end
