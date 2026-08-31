# Organizations and agencies.
#
# FileMaker source: prj_ORG__Organization (Organizations.csv, 7,191 rows).
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

  HAS_MANY = {
    "fm_rolodexes" => { via: "OrgID", label: "Rolodexes" },
    "fm_addresses" => { via: "OrgID", label: "Addresses" },
    "fm_phone_numbers" => { via: "OrgID", label: "Phone Numbers" },
    "fm_payments" => { via: "OrgID", label: "Payments" },
    "fm_participants" => { via: "OrgID", label: "Participants" },
    "fm_notes" => { via: "OrgID", label: "Notes" },
    "fm_projects" => { via: "OrgID", label: "Projects" },
    "fm_organizations" => { via: "ParentID", label: "Organizations" }
  }.freeze
end
