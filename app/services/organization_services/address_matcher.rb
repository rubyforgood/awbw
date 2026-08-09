module OrganizationServices
  # Finds the org address that corresponds to a submitted one so we update it
  # rather than create a duplicate. Matches within the same city, preferring an
  # address with the same state, then falling back to one with the same street.
  # The street fallback unifies an address we already have with a submission that
  # merely adds the state/country we were missing (same street, blank state) —
  # instead of spawning a second address for the same place.
  module AddressMatcher
    module_function

    def call(organization, city:, state: nil, street_address: nil)
      city = city&.strip
      return if city.blank?

      in_city = organization.addresses.select { |address| address.city.to_s.strip.casecmp?(city) }
      return if in_city.empty?

      state = state&.strip.to_s
      by_state = in_city.find { |address| address.state.to_s.strip.casecmp?(state) }
      return by_state if by_state

      street = street_address&.strip
      return if street.blank?
      in_city.find { |address| address.street_address.to_s.strip.casecmp?(street) }
    end
  end
end
