class StoryDecorator < Draper::Decorator
  delegate_all

  def description
    body.truncate(50)
  end

  def inactive?
    !published?
  end

  def workshop_title
    workshop&.title || external_workshop_title
  end
end
