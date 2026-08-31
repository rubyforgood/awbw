# Addresses for rolodex records and organizations.
#
# FileMaker source: prj_org_ADR__Addresses (Addresses.csv, 28,398 rows).
# Fields below live in the `data` JSON column, except the primary key, which
# the import lifts into `fm_id`. FileMaker's zc*/zg*/zs* calc, global and
# summary fields are imported too but left out here — nothing reads them.
#
#   AddrsID               PK
#   RolodexID             FK → FmRolodex
#   OrgID                 FK → FmOrganization
#   PostalCodeLookup      FK → FmPostalCode.Zipcode
#   AddrsType
#   Primacy               primary address flag
#   AddrsFormat
#   StreetNo
#   AddrsLine1
#   AddrsLine2
#   AddrsCity
#   AddrsState
#   AddrsPostalCode       stored value, mirrors PostalCodeLookup
#   AddrsCountry
#   Note
#   DateEntered
#   ModificationDateTime
class FmAddress < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "AddrsID"

  FM_LINKS = {
    "RolodexID" => "fm_rolodexes",
    "OrgID" => "fm_organizations"
  }.freeze
end
