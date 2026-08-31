# Contact log — calls, letters and mailings against a rolodex record.
#
# FileMaker source: Activity (Activity.csv).
# Fields below live in the `data` JSON column, except the primary key, which
# the import lifts into `fm_id`. FileMaker's zc*/zg*/zs* calc, global and
# summary fields are imported too but left out here — nothing reads them.
#
#   ActivityLogID    PK
#   ID               FK → FmRolodex
#   LinkID           FK → FmPayment
#   Date
#   Time
#   Type
#   Origin
#   Category
#   Pages
#   ListBy
#   Subject
#   Message
#   Message2
#   MessageForFrom
#   Comments
#   Addressee
#   Greeting
#   FirstName        denormalized from ID
#   LastName         denormalized
#   FullName         denormalized
#   TitleDept        denormalized
#   Organization     denormalized
#   TakenEntered By  field name contains a space
#   ModifiedBy
#   DateModifed      spelled this way in FileMaker
class FmActivity < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "ActivityLogID"

  FM_LINKS = {
    "ID" => "fm_rolodexes",
    "LinkID" => "fm_payments"
  }.freeze
end
