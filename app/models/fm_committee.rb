# Committees and advisory groups.
#
# FileMaker source: Committees (Committees.csv, 38 rows).
# Fields below live in the `data` JSON column, except the primary key, which
# the import lifts into `fm_id`. FileMaker's zc*/zg*/zs* calc, global and
# summary fields are imported too but left out here — nothing reads them.
#
#   CommitteeID           PK
#   CommitteeName
#   CommitteeType
#   Active
#   Description
#   MeetingSchedule
#   Procedure
#   DateEntered
#   ModificationTimeStamp
class FmCommittee < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "CommitteeID"

  FM_LINKS = {}.freeze

  HAS_MANY = {
    "fm_committee_meetings" => { via: "CommitteeID", label: "Meetings" },
    "fm_committee_members" => { via: "CommitteeID", label: "Members" }
  }.freeze
end
