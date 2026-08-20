# frozen_string_literal: true

class FmPersonnel < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "PrsnlRecID"

  FM_LINKS = {
    "PersonID" => "fm_rolodexes",
    "ProjectID" => "fm_projects"
  }.freeze
end
