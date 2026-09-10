# Items exhibited at events — art displayed at fundraisers.
#
# FileMaker source: ExhibitedItems (ExhibitedItems.csv, 2,698 rows).
# Fields below live in the `data` JSON column, except the primary key, which
# the import lifts into `fm_id`. FileMaker's zc*/zg*/zs* calc, global and
# summary fields are imported too but left out here — nothing reads them.
#
#   RecordID              PK
#   ArtRegistryItemID     FK → FmArtRegistry
#   EventID               FK → FmEvent
#   ItemName
#   ArtistDonor
#   AuctionItem
#   Layout
#   Value
#   Notes
#   DateEntered
class FmExhibitedItem < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "RecordID"

  FM_LINKS = {
    "ArtRegistryItemID" => "fm_art_registries",
    "EventID" => "fm_events"
  }.freeze
end
