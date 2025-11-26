class CommunityNewsDecorator < Draper::Decorator
  delegate_all

  def description
    body
  end

  def inactive?
    !published?
  end

end
