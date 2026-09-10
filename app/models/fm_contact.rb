# Contact log entries — links between rolodex records.
#
# FileMaker source: Contacts (Contacts.csv, 5,205 rows).
# Fields below live in the `data` JSON column, except the primary key, which
# the import lifts into `fm_id`. FileMaker's zc*/zg*/zs* calc, global and
# summary fields are imported too but left out here — nothing reads them.
#
#   ContactID             PK
#   ContacteeID           FK → FmRolodex
#   RecordID
#   PrimaryContact
#   Notes
#   EnteredBy
#   ModifiedBy
#   DateEntered
#   DateModified
class FmContact < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "ContactID"

  FM_LINKS = {
    "ContacteeID" => "fm_rolodexes"
  }.freeze
end
