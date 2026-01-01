class LinkableTestDecorator < ApplicationDecorator
  include Linkable

  def external_url
    object.external_url_value
  end
end
