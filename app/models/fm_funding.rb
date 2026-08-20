# frozen_string_literal: true

class FmFunding < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "RecordID"

  FM_LINKS = {
    "FunderID" => nil, # ambiguous — could be fm_rolodexes or fm_organizations
  }.freeze
end
