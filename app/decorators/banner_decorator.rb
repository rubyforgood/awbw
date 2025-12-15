class BannerDecorator < ApplicationDecorator

  def title
    content.truncate(50)
  end

  def detail
    content
  end

end
