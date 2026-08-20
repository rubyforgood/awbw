class FmEvent < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "EventID"

  FM_LINKS = {}.freeze

  HAS_MANY = {
    "fm_participants" => { via: "EventID", label: "Participants" }
  }.freeze
end
