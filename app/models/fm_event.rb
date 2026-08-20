# frozen_string_literal: true

class FmEvent < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "EventID"

  FM_LINKS = {
    "LinkID" => "fm_projects",
  }.freeze
end
