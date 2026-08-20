# frozen_string_literal: true

class FmService < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "RecordID"

  FM_LINKS = {
    "ProjectID" => "fm_projects",
  }.freeze
end
