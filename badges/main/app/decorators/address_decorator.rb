class AddressDecorator < ApplicationDecorator
  def title
    name
  end

  def detail(length: nil)
    "Address for #{addressable&.name}"
  end

  def url
    Rails.application.routes.url_helpers.polymorphic_path(addressable)
  end
end
