# Phone numbers for rolodex records and organizations.
#
# FileMaker source: prj_org_PHN__Phones (PhoneNumbers.csv, 33,915 rows).
# Fields below live in the `data` JSON column, except the primary key, which
# the import lifts into `fm_id`. FileMaker's zc*/zg*/zs* calc, global and
# summary fields are imported too but left out here — nothing reads them.
#
#   PhoneID               PK
#   RolodexID             FK → FmRolodex
#   OrgID                 FK → FmOrganization
#   PhoneType
#   PhoneNumber
#   Country
#   Primacy               primary number flag
#   Note
#   DateEntered
#   ModificationDateTime
class FmPhoneNumber < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "PhoneID"

  FM_LINKS = {
    "RolodexID" => "fm_rolodexes",
    "OrgID" => "fm_organizations"
  }.freeze
end
