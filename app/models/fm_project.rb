# frozen_string_literal: true

class FmProject < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "ProjectID"

  FM_LINKS = {
    "OrgID" => "fm_organizations",
    "MergerWithID" => "fm_projects",
  }.freeze
end
