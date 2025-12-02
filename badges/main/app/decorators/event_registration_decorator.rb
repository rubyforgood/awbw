class EventRegistrationDecorator < Draper::Decorator
  delegate_all


  def title
    name
  end

  def description
  end

  def main_image_url
    event.decorate.main_image_url
  end
end
