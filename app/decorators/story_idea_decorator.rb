class StoryIdeaDecorator < ApplicationDecorator
  def title
    name
  end

  def detail(length: 100)
    body&.truncate(length)
  end
end
