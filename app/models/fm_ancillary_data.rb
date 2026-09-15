# Ancillary data flags on rolodex records.
#
# FileMaker source: AncillaryData (AncillaryData.csv, 556 rows).
# Fields below live in the `data` JSON column, except the primary key, which
# the import lifts into `fm_id`. FileMaker's zc*/zg*/zs* calc, global and
# summary fields are imported too but left out here — nothing reads them.
#
#   RecordID              PK
#   RolodexID             FK → FmRolodex
#   Flag
#   FlagText
#   CreatedBy
#   ModifiedBy
#   CreationTimestamp
#   ModificationTimestamp
class FmAncillaryData < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "RecordID"

  FM_LINKS = {
    "RolodexID" => "fm_rolodexes"
  }.freeze
end
