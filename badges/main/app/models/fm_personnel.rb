# People assigned to a project, with their role and agreement status.
#
# FileMaker source: prj_PRS__Personnel (Personnel.csv, 8,907 rows).
# Fields below live in the `data` JSON column, except the primary key, which
# the import lifts into `fm_id`. FileMaker's zc*/zg*/zs* calc, global and
# summary fields are imported too but left out here — nothing reads them.
#
#   PrsnlRecID        PK, e.g. PS9999
#   PersonID          FK → FmRolodex
#   ProjectID         FK → FmProject
#   AgmtID            agreement ref, e.g. FSB02561, unlinked in the UI
#   Name              denormalized from PersonID
#   Role
#   ProjectType
#   Status
#   AgreementStatus
#   Update            annual update status
#   Notes
#   EnteredBy
#   ModifiedBy
#   DateEntered
#   DateTimeModified
class FmPersonnel < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "PrsnlRecID"

  FM_LINKS = {
    "PersonID" => "fm_rolodexes",
    "ProjectID" => "fm_projects"
  }.freeze
end
