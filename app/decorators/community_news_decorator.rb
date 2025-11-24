class CommunityNewsDecorator < Draper::Decorator
  delegate_all

  def inactive?
    !published?
  end

end
