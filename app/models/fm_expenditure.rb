# frozen_string_literal: true

class FmExpenditure < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "ExpendRecID"

  FM_LINKS = {
    "ProjectID" => "fm_projects",
  }.freeze
end
