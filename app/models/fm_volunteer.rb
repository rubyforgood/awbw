# Volunteer records — event volunteer hours and roles.
#
# FileMaker source: Volunteer (Volunteer.csv, 15,603 rows).
# Fields below live in the `data` JSON column, except the primary key, which
# the import lifts into `fm_id`. FileMaker's zc*/zg*/zs* calc, global and
# summary fields are imported too but left out here — nothing reads them.
#
#   VolID                 PK
#   VRecID                FK → FmRolodex
#   EventID               FK → FmEvent
#   FirstName
#   LastName
#   Role
#   Activity
#   Date
#   StartTime
#   EndTime
#   Hours
#   Status
#   Notes
#   DateEntered
class FmVolunteer < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "VolID"

  FM_LINKS = {
    "VRecID" => "fm_rolodexes",
    "EventID" => "fm_events"
  }.freeze
end
