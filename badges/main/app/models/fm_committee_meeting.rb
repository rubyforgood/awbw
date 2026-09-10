# Committee meeting records.
#
# FileMaker source: CommitteeMeetings (CommitteeMeetings.csv, 1 row).
# Fields below live in the `data` JSON column, except the primary key, which
# the import lifts into `fm_id`. FileMaker's zc*/zg*/zs* calc, global and
# summary fields are imported too but left out here — nothing reads them.
#
#   CtMtgID               PK
#   CommitteeID           FK → FmCommittee
#   MeetingDate
#   MeetingTime
#   DateEntered
#   ModificationTimeStamp
class FmCommitteeMeeting < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "CtMtgID"

  FM_LINKS = {
    "CommitteeID" => "fm_committees"
  }.freeze
end
