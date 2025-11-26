class BannerDecorator < Draper::Decorator
  delegate_all

  def title
    content.truncate(50)
  end

  def description
    content
  end

end
