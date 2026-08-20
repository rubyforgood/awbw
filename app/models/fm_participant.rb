# frozen_string_literal: true

class FmParticipant < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "ParticipantID"

  FM_LINKS = {
    "EventID" => "fm_events",
    "PRecID" => "fm_rolodexes",
    "OrgID" => "fm_organizations",
    "ProjectID" => "fm_projects",
    "AllocRecID" => "fm_allocations",
    "PaymentID" => "fm_payments",
  }.freeze
end
