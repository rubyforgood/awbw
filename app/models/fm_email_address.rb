# Email addresses for organizations.
#
# FileMaker source: EmailAddresses (EmailAddresses.csv, 29 rows).
# Fields below live in the `data` JSON column, except the primary key, which
# the import lifts into `fm_id`. FileMaker's zc*/zg*/zs* calc, global and
# summary fields are imported too but left out here — nothing reads them.
#
#   EmailAddrsID          PK
#   OrgID                 FK → FmOrganization
#   EmailAddress
#   EmailAddrsType
#   Primacy
#   ModificationDateTime
class FmEmailAddress < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "EmailAddrsID"

  FM_LINKS = {
    "OrgID" => "fm_organizations"
  }.freeze
end
