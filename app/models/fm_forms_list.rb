# Forms list — registration and survey form definitions.
#
# FileMaker source: FormsList (FormsList.csv, 43 rows).
# Fields below live in the `data` JSON column, except the primary key, which
# the import lifts into `fm_id`. FileMaker's zc*/zg*/zs* calc, global and
# summary fields are imported too but left out here — nothing reads them.
#
#   FormID                PK
#   FormTitle
#   FormType
#   Description
#   Active
#   StatusValueList
#   Note
class FmFormsList < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "FormID"

  FM_LINKS = {}.freeze

  HAS_MANY = {
    "fm_form_submissions" => { via: "FormID", label: "Form Submissions" }
  }.freeze
end
