# frozen_string_literal: true

class FmAddress < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "AddrsID"

  FM_LINKS = {
    "RolodexID" => "fm_rolodexes",
    "OrgID" => "fm_organizations",
  }.freeze
end
