# Invoices — billing records for services.
#
# FileMaker source: Invoice (Invoice.csv, 2,108 rows).
# Fields below live in the `data` JSON column, except the primary key, which
# the import lifts into `fm_id`. FileMaker's zc*/zg*/zs* calc, global and
# summary fields are imported too but left out here — nothing reads them.
#
#   RecordID              PK
#   InvoiceNo
#   OrgID                 FK → FmOrganization
#   RolodexID             FK → FmRolodex
#   Name
#   Company
#   Address
#   City
#   State
#   PostalCode
#   Email
#   Description
#   Price
#   Quantity
#   Unit
#   AmountPaid
#   ClientReference
#   ItemDate
#   ItemDateText
#   PaymentNotes
#   EnteredBy
#   ModifiedBy
#   DateEntered
#   DateTimeModified
#   InvoiceDate
#   DateSent
#   DatePaid
class FmInvoice < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "RecordID"

  FM_LINKS = {
    "OrgID" => "fm_organizations",
    "RolodexID" => "fm_rolodexes"
  }.freeze

  HAS_MANY = {
    "fm_line_items" => { via: "InvoiceNo", label: "Line Items" }
  }.freeze
end
