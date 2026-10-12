# Slices of a grant assigned to a project.
#
# FileMaker source: prj_ALC__Allocations (Allocations.csv, 3,099 rows).
# Fields below live in the `data` JSON column, except the primary key, which
# the import lifts into `fm_id`. FileMaker's zc*/zg*/zs* calc, global and
# summary fields are imported too but left out here — nothing reads them.
#
#   AllocRecID      PK
#   FundingRecID    FK → FmFunding
#   ProjectID       FK → FmProject
#   Year
#   Status
#   Active
#   AmountGeneral
#   AmountSupplies
#   AmountExhibit
#   Trainings       training seats granted
#   Attended
#   Paid
#   Notes
#   DateEntered
class FmAllocation < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "AllocRecID"

  FM_LINKS = {
    "FundingRecID" => "fm_funding",
    "ProjectID" => "fm_projects"
  }.freeze

  HAS_MANY = {
    "fm_participants" => { via: "AllocRecID", label: "Participants" }
  }.freeze
end
