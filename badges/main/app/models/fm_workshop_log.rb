class FmWorkshopLog < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "RecordID"

  FM_LINKS = {
    "ProjectID" => "fm_projects",
    "LeaderID" => "fm_rolodexes",
    "AgencyID" => "fm_rolodexes"
  }.freeze
end
