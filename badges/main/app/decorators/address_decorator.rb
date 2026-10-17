class AddressDecorator < ApplicationDecorator
  def title
    name
  end

  def address_type_label
    address_type&.humanize
  end

  def detail(length: nil)
    "Address for #{addressable&.name}"
  end

  def url
    Rails.application.routes.url_helpers.polymorphic_path(addressable)
  end
end
