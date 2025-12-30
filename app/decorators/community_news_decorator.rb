class CommunityNewsDecorator < ApplicationDecorator
  include ::Linkable

  def detail(length: nil)
    length ? body&.truncate(length) : body
  end

  def external_url
    object.reference_url
  end

  def inactive?
    !published?
  end
end
