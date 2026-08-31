# Programs run at an organization.
#
# FileMaker source: PRJ__Projects (Projects.csv, 1,976 rows).
# Fields below live in the `data` JSON column, except the primary key, which
# the import lifts into `fm_id`. FileMaker's zc*/zg*/zs* calc, global and
# summary fields are imported too but left out here — nothing reads them.
#
#   ProjectID                PK, e.g. P2775
#   OrgID                    FK → FmOrganization
#   MergerWithID             FK → FmProject, set when a project was merged away
#   FacilityID               rolodex ref, unlinked in the UI
#   ProjectName
#   ProjectType
#   AgencyType
#   Description
#   Status
#   ObligationStatus
#   Primary
#   PrimarySetting
#   SecondarySetting
#   PrimaryServiceArea
#   SecondaryAreas
#   LifeExperiences
#   City
#   County
#   State
#   Locality
#   District
#   LASupervisorialDistrict
#   SPA                      LA service planning area
#   International
#   StartDate
#   EndDate
#   CloseDate
#   FeePaidFor
#   FundingPotential
#   QuotationID
#   MessageText
#   Comments
#   WebID                    external/legacy key
#   SQLid                    external/legacy key
#   CreatedBy
#   EnteredBy
#   ModifiedBy
#   DateEntered
#   DateTimeModified
class FmProject < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "ProjectID"

  FM_LINKS = {
    "OrgID" => "fm_organizations",
    "MergerWithID" => "fm_projects"
  }.freeze

  HAS_MANY = {
    "fm_services" => { via: "ProjectID", label: "Services" },
    "fm_personnels" => { via: "ProjectID", label: "Personnel" },
    "fm_payments" => { via: "ProjectID", label: "Payments" },
    "fm_participants" => { via: "ProjectID", label: "Participants" },
    "fm_notes" => { via: "ProjectID", label: "Notes" },
    "fm_workshop_logs" => { via: "ProjectID", label: "Workshop Logs" },
    "fm_expenditures" => { via: "ProjectID", label: "Expenditures" },
    "fm_allocations" => { via: "ProjectID", label: "Allocations" },
    "fm_program_sponsorships" => { via: "ProgramID", label: "Program Sponsorships" },
    "fm_projects" => { via: "MergerWithID", label: "Merged Into" }
  }.freeze
end
