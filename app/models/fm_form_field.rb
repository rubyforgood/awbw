# Form field definitions — metadata for FileMaker form layouts.
#
# FileMaker source: FormFields (FormFields.csv, 611 rows).
# Fields below live in the `data` JSON column, except the primary key, which
# the import lifts into `fm_id`. FileMaker's zc*/zg*/zs* calc, global and
# summary fields are imported too but left out here — nothing reads them.
#
#   FieldNo               PK
#   FieldNameFM           FileMaker field name
#   FieldNameWP           WordPress/portal field name
#   FieldType
#   FMValue               FileMaker value list
#   WPValue               WordPress/portal value list
#   FormIDs               comma-separated form IDs
#   Notes
class FmFormField < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "FieldNo"

  FM_LINKS = {}.freeze
end
