# frozen_string_literal: true

class FmRolodex < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "ID"

  FM_LINKS = {
    "OrgID" => "fm_organizations",
    "PrimaryAddrsID" => "fm_addresses",
    "PrimaryPhoneID" => "fm_phone_numbers",
    "PrimaryContactID" => "fm_rolodexes",
    "WorksiteAddrsID" => "fm_addresses",
  }.freeze

  HAS_MANY = {
    "fm_addresses" => { via: "RolodexID", label: "Addresses" },
    "fm_phone_numbers" => { via: "RolodexID", label: "Phone Numbers" },
    "fm_payments" => { via: "RolodexID", label: "Payments" },
    "fm_activities" => { via: "ID", label: "Activities" },
    "fm_notes" => { via: "RolodexID", label: "Notes" },
    "fm_personnels" => { via: "PersonID", label: "Personnel" },
    "fm_workshop_logs" => { via: "LeaderID", label: "Workshop Logs" },
    "fm_participants" => { via: :fm_id, label: "Participations" },
  }.freeze
end
