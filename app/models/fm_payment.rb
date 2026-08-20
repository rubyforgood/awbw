# frozen_string_literal: true

class FmPayment < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "RecordID"

  FM_LINKS = {
    "RolodexID" => "fm_rolodexes",
    "OrgID" => "fm_organizations",
    "ProjectID" => "fm_projects",
    "ParticRecID" => "fm_participants",
  }.freeze
end
