# A funder sponsoring a specific program.
#
# FileMaker source: prj_PSP__ProgramSponsorships (ProgramSponsorships.csv, 608 rows).
# Fields below live in the `data` JSON column, except the primary key, which
# the import lifts into `fm_id`. FileMaker's zc*/zg*/zs* calc, global and
# summary fields are imported too but left out here — nothing reads them.
#
#   RecordID          PK, e.g. PSP0901
#   FunderID          FK → FmRolodex
#   FundingID         FK → FmFunding
#   ProgramID         FK → FmProject
#   QuotationID       unlinked in the UI
#   Status
#   StartDate
#   EndDate
#   Notes
#   MessageText
#   CreatedBy
#   ModifiedBy
#   DateCreated
#   DateTimeModified
class FmProgramSponsorship < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "RecordID"

  FM_LINKS = {
    "FunderID" => "fm_rolodexes",
    "FundingID" => "fm_funding",
    "ProgramID" => "fm_projects"
  }.freeze
end
