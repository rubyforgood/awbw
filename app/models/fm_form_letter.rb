# Form letters — mail merge templates for correspondence.
#
# FileMaker source: FormLetters (FormLetters.csv, 4,448 rows).
# Fields below live in the `data` JSON column, except the primary key, which
# the import lifts into `fm_id`. FileMaker's zc*/zg*/zs* calc, global and
# summary fields are imported too but left out here — nothing reads them.
#
#   DocID                 PK
#   SignatureID           lookup key (always 1), not a real FK to FmRolodex;
#                         the signatory name is denormalized in Signatory column
#   DocumentName
#   DocumentText
#   Page2Text
#   FooterText
#   Type
#   Pages
#   Signatory
#   Date
#   EnteredBy
#   ModifiedBy
#   DateEntered
#   DateModified
#   Notes
class FmFormLetter < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "DocID"

  FM_LINKS = {
    "SignatureID" => "fm_rolodexes"
  }.freeze
end
