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

  PORTAL_COUNTERPARTS = {
    "fm_services" => "Monthly reports",
    "fm_personnels" => "Affiliations",
    "fm_payments" => "Payments",
    "fm_participants" => "Event registrations",
    "fm_notes" => "Comments",
    "fm_workshop_logs" => "Workshop logs",
    "fm_projects" => "Organizations",
    "fm_quotations" => "Quotes"
  }.freeze

  FIELD_GROUPS = {
    "Project" => %w[ProjectName ProjectType AgencyType Status ObligationStatus Primary Description],
    "Organization & mergers" => %w[OrgID FacilityID MergerWithID],
    "Settings & service areas" => %w[PrimarySetting SecondarySetting PrimaryServiceArea SecondaryAreas LifeExperiences],
    "Location" => %w[City County State Locality District LASupervisorialDistrict SPA International],
    "Dates" => %w[StartDate EndDate CloseDate],
    "Funding" => %w[FeePaidFor FundingPotential],
    "Notes" => %w[Comments MessageText QuotationID],
    "Record keeping" => %w[ProjectID CreatedBy EnteredBy DateEntered ModifiedBy DateTimeModified WebID SQLid]
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
    "fm_projects" => { via: "MergerWithID", label: "Merged Into" },
    "fm_art_registries" => { via: "ProjectID", label: "Art Registries" },
    "fm_form_submissions" => { via: "ProjectID", label: "Form Submissions" },
    "fm_quotations" => { via: "ProjectID", label: "Quotations" }
  }.freeze

  def name
    fm_value("ProjectName") || fm_id
  end
end
