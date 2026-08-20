# frozen_string_literal: true

class FmNote < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "NoteID"

  FM_LINKS = {
    "ProjectID" => "fm_projects",
    "EventID" => "fm_events",
    "OrgID" => "fm_organizations",
    "RolodexID" => "fm_rolodexes",
    "LinkID" => nil, # polymorphic — depends on Context
  }.freeze
end
