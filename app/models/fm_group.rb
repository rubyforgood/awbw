# Groups — mailing lists and contact groups.
#
# FileMaker source: Groups (Groups.csv, 71,940 rows).
# Fields below live in the `data` JSON column, except the primary key, which
# the import lifts into `fm_id`. FileMaker's zc*/zg*/zs* calc, global and
# summary fields are imported too but left out here — nothing reads them.
#
#   GroupID               PK
#   GroupName
#   Category
#   Type
#   Active
#   Year
#   NumberType
#   Sort
#   Description
#   Note
#   GroupMemberCount
#   GroupMemberIDs
#   CreatedBy
#   ModifiedBy
#   CreationDate
#   ModificationTimeStamp
class FmGroup < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "GroupID"

  FM_LINKS = {}.freeze

  HAS_MANY = {
    "fm_group_members" => { via: "GroupID", label: "Members" }
  }.freeze
end
