# People-to-organizations join — links individuals to their affiliated orgs.
#
# FileMaker source: PeopleToOrganizations (PeopleToOrganizations.csv, 1,127 rows).
# Fields below live in the `data` JSON column, except the primary key, which
# the import lifts into `fm_id`. FileMaker's zc*/zg*/zs* calc, global and
# summary fields are imported too but left out here — nothing reads them.
#
#   RecordID              PK
#   PersonID              FK → FmRolodex
#   OrgID                 FK → FmOrganization
#   Title
#   Notes
#   ModifiedBy
#   DateEntered
#   ModificationTimeStamp
class FmPeopleToOrganization < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "RecordID"

  FM_LINKS = {
    "PersonID" => "fm_rolodexes",
    "OrgID" => "fm_organizations"
  }.freeze

  AFFILIATIONS = "Affiliations"
  FACILITATOR_AFFILIATION = "Facilitator affiliation"
  JOB_AFFILIATION = "Job affiliation"
  WIDE_GROUPS = [ AFFILIATIONS ].freeze

  FIELD_GROUPS = {
    "Person & organization" => %w[PersonID OrgID],
    AFFILIATIONS => {
      FACILITATOR_AFFILIATION => [],
      JOB_AFFILIATION => %w[Title]
    },
    "Notes" => %w[Notes],
    "Record keeping" => %w[RecordID DateEntered ModifiedBy ModificationTimeStamp]
  }.freeze

  PORTAL_COUNTERPARTS = {
    "fm_personnels" => "Affiliations",
    "fm_people_to_organizations" => "Affiliations"
  }.freeze

  HAS_MANY = {
    "fm_people_to_organizations" => { via: "PersonID", shared: true, label: "Person’s other org affiliations" },
    "fm_personnels" => { via: "PersonID", shared: true, label: "Person’s other personnel records" }
  }.freeze

  def self.for_person_at(person_id, organization_id)
    return [] if person_id.blank? || organization_id.blank?

    find_by_data("PersonID", person_id).merge(find_by_data("OrgID", organization_id)).order(:fm_id).to_a
  end

  def records_listed_under(label)
    case label
    when FACILITATOR_AFFILIATION then facilitator_affiliations
    when JOB_AFFILIATION then job_affiliations
    else []
    end
  end

  def name
    fm_phrase(fm_value("PersonID"), fm_words(fm_value("Title") || "Affiliated", fm_with("at", fm_value("OrgID"))))
  end

  private

  def facilitator_affiliations
    @facilitator_affiliations ||= FmPersonnel.for_person_at(data["PersonID"], data["OrgID"])
  end

  def job_affiliations
    @job_affiliations ||= (self.class.for_person_at(data["PersonID"], data["OrgID"]) | [ self ]).select(&:persisted?)
  end
end
