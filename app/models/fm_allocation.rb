class FmAllocation < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "AllocRecID"

  FM_LINKS = {
    "FundingRecID" => "fm_funding",
    "ProjectID" => "fm_projects"
  }.freeze

  HAS_MANY = {
    "fm_participants" => { via: "AllocRecID", label: "Participants" }
  }.freeze
end
