# Fundraising campaigns.
#
# FileMaker source: Campaigns (Campaigns.csv, 10 rows).
# Fields below live in the `data` JSON column, except the primary key, which
# the import lifts into `fm_id`. FileMaker's zc*/zg*/zs* calc, global and
# summary fields are imported too but left out here — nothing reads them.
#
#   CampaignID              PK
#   Campaign
#   CampaignStartDate
#   CampaignEndDate
#   TargetAmount
#   Current
#   Description
#   CreatedBy
#   ModifiedBy
#   CreationDate
#   ModificationTimeStamp
class FmCampaign < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "CampaignID"

  FM_LINKS = {}.freeze

  HAS_MANY = {
    "fm_donor_developers" => { via: "CampaignID", label: "Donor Developers" },
    "fm_solicitations" => { via: "CampaignID", label: "Solicitations" }
  }.freeze
end
