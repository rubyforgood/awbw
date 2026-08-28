class FmNote < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "NoteID"

  FM_LINKS = {
    "ProjectID" => "fm_projects",
    "OrgID" => "fm_organizations",
    "RolodexID" => "fm_rolodexes",
    "LinkID" => nil # polymorphic — depends on Context
  }.freeze

  CONTEXT_LINK_MAP = {
    "Project" => "fm_projects",
    "Organizations" => "fm_organizations",
    "Rolodex" => "fm_rolodexes"
  }.freeze
end
