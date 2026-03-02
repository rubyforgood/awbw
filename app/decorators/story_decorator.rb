class StoryDecorator < ApplicationDecorator
  include ::Linkable

  def detail(length: 50)
    text = rhino_body&.to_plain_text
    length ? text&.truncate(length) : text
  end

  def external_url
    object.website_url
  end

  def workshop_title
    workshop&.title || external_workshop_title
  end
end
