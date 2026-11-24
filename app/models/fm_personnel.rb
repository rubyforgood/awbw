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

  # What the FileMaker Personnel import (AffiliationServices::ImportPersonnel) writes each field to.
  PORTAL_FIELDS = {
    "PersonID" => "affiliations.person_id (by FileMaker code)",
    "ProjectID" => "affiliations.organization_id (the organization carrying the project's code)",
    "Role" => "affiliations.primary_contact (Leader or Liaison), and the import comment",
    "Status" => "affiliations.inactive (and end_date, when Inactive)",
    "Notes" => "the import comment (and affiliations.end_date, when they date an Inactive row's end)",
    "DateEntered" => "affiliations.start_date and affiliations.created_at",
    "DateTimeModified" => "affiliations.updated_at (and end_date, when nothing better dates an Inactive row's end)",
    "EnteredBy" => "affiliations.created_by_id",
    "ModifiedBy" => "affiliations.updated_by_id"
  }.freeze
  USER_LOOKUP_FIELDS = %w[EnteredBy ModifiedBy].freeze

  FIELD_GROUPS = {
    "Facilitator affiliation" => %w[Name PersonID ProjectID ProjectType Role Status],
    "Agreement & updates" => %w[AgmtID AgreementStatus Update],
    "Notes" => %w[Notes],
    "Record keeping" => %w[PrsnlRecID EnteredBy DateEntered ModifiedBy DateTimeModified]
  }.freeze

  def name
    fm_phrase(fm_value("Name"), fm_words(fm_value("Role") || "Personnel", fm_with("on", fm_value("ProjectID"))))
  end
end
