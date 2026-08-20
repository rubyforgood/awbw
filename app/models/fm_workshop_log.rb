# frozen_string_literal: true

class FmWorkshopLog < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "RecordID"

  FM_LINKS = {
    "ProjectID" => "fm_projects",
    "LeaderID" => "fm_rolodexes",
    "AgencyID" => "fm_organizations",
  }.freeze
end
