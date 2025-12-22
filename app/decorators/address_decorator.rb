class AddressDecorator < ApplicationDecorator

  def title
    name
  end

  def detail
    "Address for #{addressable&.name}"
  end

  def url
    Rails.application.routes.url_helpers.polymorphic_path(addressable)
  end

end
