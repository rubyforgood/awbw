module OrganizationServices
  # Finds the org address that corresponds to a submitted one so we update it
  # rather than create a duplicate. Tries, in order of how strongly each pins the
  # address down:
  #
  #   1. same city + same state, preferring one whose street also matches — an org
  #      with several offices in one city can't be told apart by state alone, and
  #      picking the wrong one would rewrite a real address into a duplicate
  #   2. same city + same street — unifies an address we already have with a
  #      submission that merely adds the state/country we were missing
  #   3. same street + same ZIP, in any city — a ZIP pins a place far more tightly
  #      than a city name, so this reunites an address whose city was respelled
  #      between submissions ("Ventura" / "San Buenaventura") without merging two real
  #      offices that share a street name in different towns
  #
  # Every comparison goes through AddressNormalizer, so "St. Louis" matches
  # "Saint Louis" and "123 N Main St" matches "123 North Main Street".
  #
  # Because 3 can match across cities, the city the caller submitted may differ
  # from the one on file; UpsertAddress keeps the saved city and ProfileDiff flags
  # the difference. Module function, used by both address services.
  module AddressMatcher
    module_function

    def call(organization, city:, state: nil, street_address: nil, zip_code: nil)
      city = AddressNormalizer.city(city)
      return if city.blank?

      addresses = organization.addresses.to_a
      in_city = addresses.select { |address| AddressNormalizer.city(address.city) == city }
      street = AddressNormalizer.street(street_address)

      state_key = AddressNormalizer.state(state)
      in_state = in_city.select { |address| AddressNormalizer.state(address.state) == state_key }
      by_state = same_street(in_state, street) || in_state.first
      return by_state if by_state

      return if street.blank?

      by_street = same_street(in_city, street)
      return by_street if by_street

      zip = AddressNormalizer.zip(zip_code)
      return if zip.blank?
      addresses.find do |address|
        AddressNormalizer.street(address.street_address) == street && AddressNormalizer.zip(address.zip_code) == zip
      end
    end

    def same_street(addresses, street)
      return if street.blank?

      addresses.find { |address| AddressNormalizer.street(address.street_address) == street }
    end
  end
end
