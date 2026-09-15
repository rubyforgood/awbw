# Invoice line items — individual billing line entries.
#
# FileMaker source: LineItem (LineItem.csv, 103 rows).
# Fields below live in the `data` JSON column, except the primary key, which
# the import lifts into `fm_id`. FileMaker's zc*/zg*/zs* calc, global and
# summary fields are imported too but left out here — nothing reads them.
#
#   ItemID                PK
#   InvoiceNo             FK → FmInvoice
#   Description
#   Category
#   Price
#   Quantity
#   Unit
#   Date
#   RefID
#   Note
#   ModifiedBy
#   DateTimeModified
class FmLineItem < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "ItemID"

  FM_LINKS = {
    "InvoiceNo" => "fm_invoices"
  }.freeze
end
