class FmFunding < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "RecordID"

  FM_LINKS = {
    "FunderID" => "fm_rolodexes"
  }.freeze

  HAS_MANY = {
    "fm_allocations" => { via: "FundingRecID", label: "Allocations" },
    "fm_program_sponsorships" => { via: "FundingID", label: "Program Sponsorships" }
  }.freeze
end
