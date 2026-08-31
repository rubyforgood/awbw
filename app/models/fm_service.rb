# Monthly participant counts per project.
#
# FileMaker source: prj_SRV__Service (Service.csv, 69,590 rows).
# Fields below live in the `data` JSON column, except the primary key, which
# the import lifts into `fm_id`. FileMaker's zc*/zg*/zs* calc, global and
# summary fields are imported too but left out here — nothing reads them.
#
#   RecordID          PK
#   ProjectID         FK → FmProject
#   Year
#   Month
#   NewAdult
#   NewTeen
#   NewChild
#   OngoingAdult
#   OngoingTeen
#   OngoingChild
#   Acknowledgment
#   LateCard          report filed late
#   CreatedBy
#   ModifiedBy
#   DateTimeCreated
#   DateTimeModified
class FmService < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "RecordID"

  FM_LINKS = {
    "ProjectID" => "fm_projects"
  }.freeze
end
