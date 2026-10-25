class AddressDecorator < ApplicationDecorator
  def title
    name
  end

  def address_type_label
    address_type&.humanize
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

  def state_as_text?
    AddressLocality.outside_usa?(state, default_country)
  end

  def default_locality
    return locality if locality.present?

    Address::OUTSIDE_USA if state_as_text?
  end

  # A new address starts in the country of the owner's saved address (primary first), else the US.
  def default_country
    return country if persisted? || country.present?

    saved = addressable&.addresses&.select { |address| address.persisted? && address.country.present? } || []
    (saved.find(&:primary?) || saved.first)&.country || Address::DEFAULT_COUNTRY
  end
end
