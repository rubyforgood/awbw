module OrganizationServices
  # Finds the org address that corresponds to a submitted one so we update it
  # rather than create a duplicate. Tries, in order of how strongly each pins the
  # address down:
  #
  #   1. same city + same state
  #   2. same city + same street — unifies an address we already have with a
  #      submission that merely adds the state/country we were missing
  #   3. same street + same ZIP, in any city — a ZIP pins a place far more tightly
  #      than a city name, so this reunites an address whose city was respelled
  #      between submissions ("St. Louis" / "Saint Louis") without merging two real
  #      offices that share a street name in different towns
  #
  # Because 3 can match across cities, the city the caller submitted may differ
  # from the one on file; UpsertAddress keeps the saved city and ProfileDiff flags
  # the difference. Module function, used by both address services.
  module AddressMatcher
    module_function

    def call(organization, city:, state: nil, street_address: nil, zip_code: nil)
      city = city&.strip
      return if city.blank?

      addresses = organization.addresses.to_a
      in_city = addresses.select { |address| address.city.to_s.strip.casecmp?(city) }

      by_state = in_city.find { |address| address.state.to_s.strip.casecmp?(state&.strip.to_s) }
      return by_state if by_state

      street = street_address&.strip
      return if street.blank?

      by_street = in_city.find { |address| address.street_address.to_s.strip.casecmp?(street) }
      return by_street if by_street

      zip = zip_code&.strip
      return if zip.blank?
      addresses.find do |address|
        address.street_address.to_s.strip.casecmp?(street) && address.zip_code.to_s.strip.casecmp?(zip)
      end
    end
  end
end
