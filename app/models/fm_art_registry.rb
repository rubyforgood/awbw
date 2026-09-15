# Art registry — artworks created by program participants.
#
# FileMaker source: ArtRegistry (ArtRegistry.csv, 9,601 rows).
# Fields below live in the `data` JSON column, except the primary key, which
# the import lifts into `fm_id`. FileMaker's zc*/zg*/zs* calc, global and
# summary fields are imported too but left out here — nothing reads them.
#
#   ItemID              PK
#   ArtistID            FK → FmRolodex
#   BuyerID             FK → FmRolodex
#   ProjectID           FK → FmProject
#   ArtRegistryNo
#   ArtTitle
#   ArtistFirstName
#   ArtistLastName
#   ArtistAge
#   BuyerFirstName
#   BuyerLastName
#   BuyerName
#   Caption
#   CulturalStatus
#   AnonymityStatus
#   Medium
#   YearCreated
#   Documentation
#   ReleaseName
#   SaleDate
#   SalePrice
#   LoanStatus
#   NonSurv
#   Notes
#   ProgramName
#   ReturnedToArtist
#   ReturnToArtist
#   DateReturnedToArtist
#   ThankedArtist
#   ArtistThankedDate
#   SAG
#   EnteredBy
#   DateEntered
#   DateModified
class FmArtRegistry < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "ItemID"

  FM_LINKS = {
    "ArtistID" => "fm_rolodexes",
    "BuyerID" => "fm_rolodexes",
    "ProjectID" => "fm_projects"
  }.freeze

  HAS_MANY = {
    "fm_art_purchases" => { via: "ArtRegistryID", label: "Art Purchases" },
    "fm_exhibited_items" => { via: "ArtRegistryItemID", label: "Exhibited Items" }
  }.freeze
end
