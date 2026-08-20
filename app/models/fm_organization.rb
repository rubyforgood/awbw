# frozen_string_literal: true

class FmOrganization < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "OrgID"

  FM_LINKS = {
    "ParentID" => "fm_organizations",
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
  }.freeze
end
