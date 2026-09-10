# Art purchases — sales of art registry items.
#
# FileMaker source: ArtPurchases (ArtPurchases.csv, 230 rows).
# Fields below live in the `data` JSON column, except the primary key, which
# the import lifts into `fm_id`. FileMaker's zc*/zg*/zs* calc, global and
# summary fields are imported too but left out here — nothing reads them.
#
#   PurchaseID          PK
#   ArtRegistryID       FK → FmArtRegistry
#   ArtRegistryNo
#   ArtTitle
#   BuyerID             FK → FmRolodex
#   LoanStatus
#   PurchaseDate
#   ReleaseStatus
#   AmountPaid
class FmArtPurchase < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "PurchaseID"

  FM_LINKS = {
    "ArtRegistryID" => "fm_art_registries",
    "BuyerID" => "fm_rolodexes"
  }.freeze
end
