# Donor solicitations — individual ask records within a campaign.
#
# FileMaker source: Solicitations (Solicitations.csv, 11,819 rows).
# Fields below live in the `data` JSON column, except the primary key, which
# the import lifts into `fm_id`. FileMaker's zc*/zg*/zs* calc, global and
# summary fields are imported too but left out here — nothing reads them.
#
#   SolicitationID        PK
#   CampaignID            FK → FmCampaign
#   DonorDevRecID         FK → FmDonorDeveloper
#   DonorID               FK → FmRolodex
#   Status
#   TargetAmount
#   GiftCurYrAmt
#   GiftFirstAmt
#   GiftFirstDate
#   GiftLargestAmt
#   GiftLargestDate
#   GiftLatestAmt
#   GiftLatestDate
#   GiftTotalYr1Prev
#   GiftTotalYr2Prev
#   DonorLevelCurrYr
#   DonorLevelPrevYr
#   NameListing
#   Select
#   Comments
#   DateEntered
#   LastUpdate
class FmSolicitation < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "SolicitationID"

  FM_LINKS = {
    "CampaignID" => "fm_campaigns",
    "DonorDevRecID" => "fm_donor_developers",
    "DonorID" => "fm_rolodexes"
  }.freeze
end
