class StoryDecorator < ApplicationDecorator
  include ::Linkable

  def detail(length: 50)
    body&.truncate(length)
  end

  def external_url
    object.website_url
  end

  def inactive?
    !published?
  end

  def workshop_title
    workshop&.title || external_workshop_title
  end
end
