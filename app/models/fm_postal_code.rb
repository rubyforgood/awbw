# ZIP code reference data.
#
# FileMaker source: prj_PZC__CityState (PostalCodes.csv, 80,134 rows).
# Fields below live in the `data` JSON column, except the primary key, which
# the import lifts into `fm_id`. FileMaker's zc*/zg*/zs* calc, global and
# summary fields are imported too but left out here — nothing reads them.
#
#   Zipcode          PK
#   City
#   State
#   County
#   FIPS
#   Type
#   Preferred
#   PrefSort
#   AreaCode
#   TimeZone
#   DaylightSavings
#   Latitude
#   Longitude
#   Population
class FmPostalCode < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "Zipcode"

  FM_LINKS = {}.freeze

  # The county a US ZIP (or ZIP+4) lies in, unless the ZIP belongs to a different state.
  def self.county_for(zip_code, state:)
    zip = zip_code.to_s.strip[/\A\d{5}/]
    return unless zip

    data = find_by(fm_id: zip)&.data || {}
    return if data["State"].present? && AddressNormalizer.state(data["State"]) != AddressNormalizer.state(state)

    data["County"].to_s.squish.presence
  end

  def name
    fm_words([ fm_value("City"), fm_value("State") ].compact.join(", "), fm_id)
  end
end
