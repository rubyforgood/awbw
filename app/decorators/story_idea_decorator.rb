class StoryIdeaDecorator < ApplicationDecorator
  def title
    name
  end

  def detail(length: 100)
    text = rhino_body&.to_plain_text
    length ? text&.truncate(length) : text
  end
end
