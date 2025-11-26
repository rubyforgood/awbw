class StoryIdeaDecorator < Draper::Decorator
  delegate_all


  def title
    name
  end

  def description
    body.truncate(100)
  end
end
