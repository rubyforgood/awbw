# Spending charged against a project.
#
# FileMaker source: prj_EXP__Expenditure (Expenditure.csv, 5,314 rows).
# Fields below live in the `data` JSON column, except the primary key, which
# the import lifts into `fm_id`. FileMaker's zc*/zg*/zs* calc, global and
# summary fields are imported too but left out here — nothing reads them.
#
#   ExpendRecID  PK, e.g. X5510
#   ProjectID    FK → FmProject
#   Type
#   Category
#   Name
#   Description
#   Notes
#   Amount
#   CheckNo
#   DatePaid
#   DateEntered
class FmExpenditure < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "ExpendRecID"

  FM_LINKS = {
    "ProjectID" => "fm_projects"
  }.freeze
end
