# frozen_string_literal: true

class FmPhoneNumber < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "PhoneID"

  FM_LINKS = {
    "RolodexID" => "fm_rolodexes",
    "OrgID" => "fm_organizations",
  }.freeze
end
