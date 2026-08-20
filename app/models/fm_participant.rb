# frozen_string_literal: true

class FmParticipant < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "ParticipantID"

  FM_LINKS = {
    "EventID" => "fm_events",
    "OrgID" => "fm_organizations",
    "ProjectID" => "fm_projects",
    "AllocRecID" => "fm_allocations",
    "PaymentID" => "fm_payments",
  }.freeze

  HAS_MANY = {
    "fm_rolodexes" => { via: :fm_id, label: "Rolodex" },
  }.freeze
end
