# frozen_string_literal: true

class FmAllocation < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "AllocRecID"

  FM_LINKS = {
    "FundingRecID" => "fm_funding",
    "ProjectID" => "fm_projects",
  }.freeze
end
