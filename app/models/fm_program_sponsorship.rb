# frozen_string_literal: true

class FmProgramSponsorship < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "RecordID"

  FM_LINKS = {
    "FunderID" => "fm_rolodexes",
    "FundingID" => "fm_funding",
    "ProgramID" => "fm_projects",
  }.freeze
end
