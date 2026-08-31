class CommunityNewsDecorator < ApplicationDecorator
  include ::Linkable

  def detail(length: nil)
    text = rhino_body&.to_plain_text
    length ? text&.truncate(length) : text
  end

  def external_url
    object.reference_url
  end
end
