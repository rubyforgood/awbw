class StoryDecorator < Draper::Decorator
  delegate_all

  def inactive?
    !published?
  end

  def workshop_title
    workshop&.title || external_workshop_title
  end
end
