# Trainings, fundraisers and other events.
#
# FileMaker source: prj_EVT__Events (Events.csv, 3,468 rows).
# Fields below live in the `data` JSON column, except the primary key, which
# the import lifts into `fm_id`. FileMaker's zc*/zg*/zs* calc, global and
# summary fields are imported too but left out here — nothing reads them.
#
#   EventID                PK, e.g. E4037
#   LinkID                 unlinked in the UI
#   Title
#   Category
#   Type
#   Group
#   Description
#   Notes
#   Comments
#   ItemDescription
#   Available              open for registration
#   EventDate
#   EndDate
#   StartTime
#   EndTime
#   Year
#   Location
#   Organizer
#   Fee
#   MinParticipants
#   MaxParticipants
#   EstimatedParticipants
#   EventCostItems
#   EventCosts
#   EventCostsInKind
#   EnteredBy
#   ModifiedBy
#   DateEntered
#   DateTimeModified
class FmEvent < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "EventID"

  FM_LINKS = {}.freeze

  HAS_MANY = {
    "fm_participants" => { via: "EventID", label: "Participants" }
  }.freeze
end
