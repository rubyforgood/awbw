class FmActivity < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "ActivityLogID"

  FM_LINKS = {
    "ID" => "fm_rolodexes",
    "LinkID" => "fm_payments"
  }.freeze
end
