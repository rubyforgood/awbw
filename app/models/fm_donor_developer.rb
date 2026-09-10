# Donor development records — fundraising advocates linked to campaigns.
#
# FileMaker source: DonorDevelopers (DonorDevelopers.csv, 165 rows).
# Fields below live in the `data` JSON column, except the primary key, which
# the import lifts into `fm_id`. FileMaker's zc*/zg*/zs* calc, global and
# summary fields are imported too but left out here — nothing reads them.
#
#   DonorDevRecID         PK
#   CampaignID            FK → FmCampaign
#   RolodexID             FK → FmRolodex
#   GoalAmount
#   NameListing
#   OtherAdvocateRaised
#   Notes
#   DateEntered
#   ModificationTimestamp
class FmDonorDeveloper < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "DonorDevRecID"

  FM_LINKS = {
    "CampaignID" => "fm_campaigns",
    "RolodexID" => "fm_rolodexes"
  }.freeze

  HAS_MANY = {
    "fm_solicitations" => { via: "DonorDevRecID", label: "Solicitations" }
  }.freeze
end
