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

  AFFILIATIONS = "Affiliations"
  FACILITATOR_AFFILIATION = "Facilitator affiliation"
  JOB_AFFILIATION = "Job affiliation"
  WIDE_GROUPS = [ AFFILIATIONS ].freeze

  FIELD_GROUPS = {
    "Person & project" => %w[Name PersonID ProjectID ProjectType],
    "Agreement & updates" => %w[AgmtID AgreementStatus Update],
    AFFILIATIONS => {
      FACILITATOR_AFFILIATION => %w[Role Status],
      JOB_AFFILIATION => []
    },
    "Notes" => %w[Notes],
    "Record keeping" => %w[PrsnlRecID EnteredBy DateEntered ModifiedBy DateTimeModified]
  }.freeze

  # A personnel row names a project, so its organization is the one that project belongs to.
  def self.for_person_at(person_id, organization_id)
    return [] if person_id.blank? || organization_id.blank?

    personnel = find_by_data("PersonID", person_id).order(:fm_id).to_a
    project_ids = FmProject.where(fm_id: personnel.map { |row| row.data["ProjectID"] })
                           .select { |project| project.data["OrgID"] == organization_id }.map(&:fm_id)
    personnel.select { |row| project_ids.include?(row.data["ProjectID"]) }
  end

  def records_listed_under(label)
    case label
    when FACILITATOR_AFFILIATION then facilitator_affiliations
    when JOB_AFFILIATION then job_affiliations
    else []
    end
  end

  def name
    fm_phrase(fm_value("Name"), fm_words(fm_value("Role") || "Personnel", fm_with("on", fm_value("ProjectID"))))
  end

  private

  def organization_id
    @organization_id ||= FmProject.find_by_fm_id(data["ProjectID"])&.data&.dig("OrgID")
  end

  def facilitator_affiliations
    @facilitator_affiliations ||= (self.class.for_person_at(data["PersonID"], organization_id) | [ self ]).select(&:persisted?)
  end

  def job_affiliations
    @job_affiliations ||= FmPeopleToOrganization.for_person_at(data["PersonID"], organization_id)
  end
end
