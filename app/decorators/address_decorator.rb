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
    AddressLocality.outside_usa?(default_state, default_country)
  end

  # A new address starts from the owner's saved address (primary first); its country
  # falls back to the Settings return address's.
  def default_country
    return country if persisted? || country.present?

    saved_address&.country.presence || Setting.default_address_country
  end

  def default_state
    return state if persisted? || state.present?

    saved_address&.state
  end

  # California outside LA and Orange counties is a person's call, so it stays blank.
  def default_locality
    return locality if locality.present?
    return saved_address.locality if new_record? && saved_address&.locality.present?
    return Address::OUTSIDE_USA if state_as_text?

    Address::OUTSIDE_CA if default_state.present? && AddressNormalizer.state(default_state) != AddressLocality::CALIFORNIA
  end

  private

  def saved_address
    return @saved_address if defined?(@saved_address)

    saved = addressable&.addresses&.select(&:persisted?) || []
    @saved_address = saved.find(&:primary?) || saved.first
  end
end
