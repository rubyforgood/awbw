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

  # A new address starts from the owner's saved address; its country falls back to the
  # Settings return address's.
  def default_country
    return country if persisted? || country.present?

    saved_address&.country.presence || Setting.default_address_country
  end

  def default_state
    return state if persisted? || state.present?

    saved_address&.state
  end

  # Anything AddressLocality can't settle from the address itself — California outside
  # LA and Orange counties, a state spelling no US state answers to — stays blank for
  # a person to choose.
  def default_locality
    return locality if locality.present?
    return saved_address.locality if new_record? && saved_address&.locality.present?

    derived = AddressLocality.for(city: city, state: default_state, country: default_country, county: county)
    derived unless derived == Address::UNKNOWN_LOCALITY
  end

  private

  # The saved address a new one copies: an active address before a retired one, and the
  # most recently updated of those.
  def saved_address
    return @saved_address if defined?(@saved_address)

    saved = addressable&.addresses&.select(&:persisted?) || []
    @saved_address = saved.min_by { |address| [ address.inactive? ? 1 : 0, -address.updated_at.to_f ] }
  end
end
