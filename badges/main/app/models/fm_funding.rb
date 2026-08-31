# Grants and other funding sources.
#
# FileMaker source: prj_FND__FundingviaTempID (Funding.csv, 1,391 rows).
# Fields below live in the `data` JSON column, except the primary key, which
# the import lifts into `fm_id`. FileMaker's zc*/zg*/zs* calc, global and
# summary fields are imported too but left out here — nothing reads them.
#
#   RecordID           PK, e.g. F1581
#   FunderID           FK → FmRolodex
#   ProgramScope
#   GeographicScope
#   ScopeGranted
#   Status
#   Category
#   GrantType
#   Source
#   Active
#   NonAllocated
#   Purpose
#   Notes
#   NameTemp
#   Submission
#   RequestAmount
#   AmountGranted
#   GeneralBudget
#   SupplyBudget
#   ExhibitBudget
#   TrainingsBudgeted
#   CostPerTraining
#   StartDate
#   EndDate
#   Month
#   KeyYearOverride
#   DateReq
#   SubmissionDate
#   FirmDeadline
#   TargetDeadline
#   NotificationDate
#   NotifyDateEst
#   ReportDueDate
#   ReportDescription
#   ReportIn
#   DateReportSent
#   ReconciliationDue
#   EnteredBy
#   ModifiedBy
#   Date Entered       field name contains a space
#   DateModified
class FmFunding < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "RecordID"

  FM_LINKS = {
    "FunderID" => "fm_rolodexes"
  }.freeze

  HAS_MANY = {
    "fm_allocations" => { via: "FundingRecID", label: "Allocations" },
    "fm_program_sponsorships" => { via: "FundingID", label: "Program Sponsorships" }
  }.freeze
end
