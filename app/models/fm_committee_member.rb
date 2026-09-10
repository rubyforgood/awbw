# Committee membership records.
#
# FileMaker source: CommitteeMembers (CommitteeMembers.csv, 691 rows).
# Fields below live in the `data` JSON column, except the primary key, which
# the import lifts into `fm_id`. FileMaker's zc*/zg*/zs* calc, global and
# summary fields are imported too but left out here — nothing reads them.
#
#   CMRecID               PK
#   CommitteeID           FK → FmCommittee
#   MemberID              FK → FmRolodex
#   Active
#   Role
#   TermStart
#   TermEnd
#   DateEntered
#   ModificationTimestamp
class FmCommitteeMember < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "CMRecID"

  FM_LINKS = {
    "CommitteeID" => "fm_committees",
    "MemberID" => "fm_rolodexes"
  }.freeze
end
