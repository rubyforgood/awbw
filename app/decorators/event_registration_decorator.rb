class EventRegistrationDecorator < ApplicationDecorator

  def title
    name
  end

  def detail
  end

  def main_image_url
    event.decorate.main_image_url
  end

end
