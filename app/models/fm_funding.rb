# frozen_string_literal: true

class FmFunding < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "RecordID"

  FM_LINKS = {
    "FunderID" => "fm_rolodexes",
  }.freeze
end
