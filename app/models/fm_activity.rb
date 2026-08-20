# frozen_string_literal: true

class FmActivity < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "ActivityLogID"

  FM_LINKS = {
    "ID" => "fm_rolodexes",
    "LinkID" => nil, # polymorphic — depends on Context
  }.freeze
end
