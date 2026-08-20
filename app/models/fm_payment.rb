# frozen_string_literal: true

class FmPayment < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "RecordID"

  FM_LINKS = {
    "RolodexID" => "fm_rolodexes",
    "OrgID" => "fm_organizations",
    "ProjectID" => "fm_projects",
  }.freeze

  HAS_MANY = {
    "fm_activities" => { via: "LinkID", label: "Activities" },
    "fm_participants" => { via: "PaymentID", label: "Participants" },
  }.freeze
end
