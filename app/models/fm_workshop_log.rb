# One submitted workshop report.
#
# FileMaker source: WSL__WorkshopLog (WorkshopLogs.csv, 10,859 rows).
# Fields below live in the `data` JSON column, except the primary key, which
# the import lifts into `fm_id`. FileMaker's zc*/zg*/zs* calc, global and
# summary fields are imported too but left out here — nothing reads them.
#
#   RecordID            PK
#   ProjectID           FK → FmProject
#   LeaderID            FK → FmRolodex
#   AgencyID            FK → FmRolodex
#   LeaderName          denormalized from LeaderID
#   WorkshopID          e.g. W0421
#   sqlWorkshopID       external/legacy key
#   WebReportID         external/legacy key
#   ReportSubmissionID  external/legacy key
#   LinkIDs             unlinked in the UI
#   WorkshopTitle
#   WorkshopDate
#   ReportDate
#   Year__c
#   MonthNumber__c
#   TotalNew
#   TotalNewTeen
#   TotalNewChild
#   TotalOngoing
#   TotalOngoingTeen
#   TotalOngoingChild
#   AgesAdult
#   AgesTeen
#   AgesChild
#   Materials
#   Notes
#   EnteredBy
#   DateEntered
class FmWorkshopLog < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "RecordID"

  FM_LINKS = {
    "ProjectID" => "fm_projects",
    "LeaderID" => "fm_rolodexes",
    "AgencyID" => "fm_rolodexes"
  }.freeze
end
