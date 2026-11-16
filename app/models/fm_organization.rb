# Organizations and agencies.
#
# FileMaker source: prj_ORG__Organization (Organizations.csv, 7,240 rows).
# Fields below live in the `data` JSON column, except the primary key, which
# the import lifts into `fm_id`. FileMaker's zc*/zg*/zs* calc, global and
# summary fields are imported too but left out here — nothing reads them.
#
#   OrgID                 PK, e.g. ORG07206
#   ParentID              FK → FmOrganization
#   MainID                unlinked in the UI
#   OrgName
#   OrgType
#   Classification
#   Status
#   Hierarchy
#   Website
#   Description
#   Mission
#   Facilities
#   Interests
#   FundingPriorities
#   Meetings
#   Newsletter
#   Keywords
#   Comments
#   OutreachStatus
#   OutreachDate
#   CreatedBy
#   ModifiedBy
#   CreationDate
#   ModificationDateTime
class FmOrganization < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "OrgID"

  FM_LINKS = {
    "ParentID" => "fm_organizations"
  }.freeze

  # What the FileMaker organization import (OrganizationServices::ImportOrgs) writes each field to.
  PORTAL_FIELDS = {
    "OrgName" => "organizations.name",
    "OrgType" => "organizations.organization_type (and school, organization_type_other)",
    "Status" => "organizations.organization_status_id (by status name)",
    "Website" => "organizations.website_url",
    "Description" => "organizations.description",
    "Mission" => "organizations.mission_vision_values",
    "CreationDate" => "organizations.created_at",
    "ModificationDateTime" => "organizations.updated_at",
    "CreatedBy" => "organizations.created_by_id",
    "ModifiedBy" => "organizations.updated_by_id"
  }.freeze
  USER_LOOKUP_FIELDS = %w[CreatedBy ModifiedBy].freeze

  PORTAL_COUNTERPARTS = {
    "fm_rolodexes" => "People",
    "fm_addresses" => "Addresses",
    "fm_phone_numbers" => "Contact methods",
    "fm_payments" => "Payments",
    "fm_participants" => "Event registrations",
    "fm_notes" => "Comments",
    "fm_projects" => "Organizations",
    "fm_organizations" => "Organizations",
    "fm_invoices" => "Invoices",
    "fm_people_to_organizations" => "Affiliations"
  }.freeze

  FIELD_GROUPS = {
    "Organization" => %w[OrgName OrgType Classification Status Website],
    "Hierarchy" => %w[Hierarchy ParentID MainID],
    "About" => %w[Description Mission Facilities Interests FundingPriorities Meetings Newsletter],
    "Outreach" => %w[OutreachStatus OutreachDate],
    "Notes" => %w[Comments Keywords],
    "Record keeping" => %w[OrgID CreatedBy CreationDate ModifiedBy ModificationDateTime]
  }.freeze

  HAS_MANY = {
    "fm_rolodexes" => { via: "OrgID", label: "Rolodexes" },
    "fm_addresses" => { via: "OrgID", label: "Addresses" },
    "fm_phone_numbers" => { via: "OrgID", label: "Phone Numbers" },
    "fm_payments" => { via: "OrgID", label: "Payments" },
    "fm_participants" => { via: "OrgID", label: "Participants" },
    "fm_notes" => { via: "OrgID", label: "Notes" },
    "fm_projects" => { via: "OrgID", label: "Projects" },
    "fm_organizations" => { via: "ParentID", label: "Organizations" },
    "fm_email_addresses" => { via: "OrgID", label: "Email Addresses" },
    "fm_form_submissions" => { via: "OrgID", label: "Form Submissions" },
    "fm_invoices" => { via: "OrgID", label: "Invoices" },
    "fm_people_to_organizations" => { via: "OrgID", label: "People Affiliations" }
  }.freeze

  def name
    fm_value("OrgName") || fm_id
  end
end
