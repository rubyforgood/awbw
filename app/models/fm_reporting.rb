# Funding reporting obligations — report due dates and submission tracking.
#
# FileMaker source: Reporting (Reporting.csv, 734 rows).
# Fields below live in the `data` JSON column, except the primary key, which
# the import lifts into `fm_id`. FileMaker's zc*/zg*/zs* calc, global and
# summary fields are imported too but left out here — nothing reads them.
#
#   ReportID              PK
#   FundingRecordID       FK → FmFunding
#   ReportDescription
#   ReportDueDate
#   DateReportSent
#   ReconciliationDue
class FmReporting < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "ReportID"

  FM_LINKS = {
    "FundingRecordID" => "fm_fundings"
  }.freeze
end
