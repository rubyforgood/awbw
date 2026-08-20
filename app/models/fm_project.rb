# frozen_string_literal: true

class FmProject < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "ProjectID"

  FM_LINKS = {
    "OrgID" => "fm_organizations",
    "MergerWithID" => "fm_projects",
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
  }.freeze
end
