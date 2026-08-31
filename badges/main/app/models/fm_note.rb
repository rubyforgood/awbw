# Polymorphic note log — Context names the table, LinkID the record.
#
# FileMaker source: prj_NTS__Notes (Notes.csv, 616 rows).
# Fields below live in the `data` JSON column, except the primary key, which
# the import lifts into `fm_id`. FileMaker's zc*/zg*/zs* calc, global and
# summary fields are imported too but left out here — nothing reads them.
#
#   NoteID            PK, e.g. N00643
#   Context           discriminator: Project, Organizations or Rolodex
#   LinkID            FK → the table named by Context
#   ProjectID         FK → FmProject, redundant with LinkID
#   OrgID             FK → FmOrganization, redundant with LinkID
#   RolodexID         FK → FmRolodex, redundant with LinkID
#   EventID           FK → FmEvent, never populated
#   Date
#   Subject
#   Note
#   Category
#   Classification
#   Status
#   EnteredBy
#   ModifiedBy
#   DateTimeModified
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
