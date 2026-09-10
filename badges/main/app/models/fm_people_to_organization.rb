# People-to-organizations join — links individuals to their affiliated orgs.
#
# FileMaker source: PeopleToOrganizations (PeopleToOrganizations.csv, 1,127 rows).
# Fields below live in the `data` JSON column, except the primary key, which
# the import lifts into `fm_id`. FileMaker's zc*/zg*/zs* calc, global and
# summary fields are imported too but left out here — nothing reads them.
#
#   RecordID              PK
#   PersonID              FK → FmRolodex
#   OrgID                 FK → FmOrganization
#   Title
#   Notes
#   ModifiedBy
#   DateEntered
#   ModificationTimeStamp
class FmPeopleToOrganization < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "RecordID"

  FM_LINKS = {
    "PersonID" => "fm_rolodexes",
    "OrgID" => "fm_organizations"
  }.freeze
end
