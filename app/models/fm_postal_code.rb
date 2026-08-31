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
end
