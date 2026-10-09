class AddressDecorator < ApplicationDecorator
  def title
    name
  end

  # Names the address an owner has marked for invoices, so whoever is billing can see
  # which one dynamic invoices pick without opening the organization.
  def picker_label
    return name unless invoice_address?

    "#{name} — invoice address"
  end

  def detail(length: nil)
    "Address for #{addressable&.name}"
  end

  def url
    Rails.application.routes.url_helpers.polymorphic_path(addressable)
  end
end
