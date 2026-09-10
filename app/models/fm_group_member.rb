# Group membership records.
#
# FileMaker source: GroupMembers (GroupMembers.csv, 18 rows).
# Fields below live in the `data` JSON column, except the primary key, which
# the import lifts into `fm_id`. FileMaker's zc*/zg*/zs* calc, global and
# summary fields are imported too but left out here — nothing reads them.
#
#   RecordID              PK
#   GroupID               FK → FmGroup
#   ContactID             FK → FmRolodex
#   Number
#   Status
#   Notes
#   EnteredBy
#   ModifiedBy
#   DateEntered
#   DateTimeModified
class FmGroupMember < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "RecordID"

  FM_LINKS = {
    "GroupID" => "fm_groups",
    "ContactID" => "fm_rolodexes"
  }.freeze
end
