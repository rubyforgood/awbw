# frozen_string_literal: true

class FmEvent < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "EventID"

  FM_LINKS = {
    "LinkID" => "fm_projects",
  }.freeze

  HAS_MANY = {
    "fm_participants" => { via: "EventID", label: "Participants" },
    "fm_notes" => { via: "EventID", label: "Notes" },
  }.freeze
end
