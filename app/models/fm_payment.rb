# Donations and payments received.
#
# FileMaker source: prj_PMT__Payment (Payments.csv, 27,146 rows).
# Fields below live in the `data` JSON column, except the primary key, which
# the import lifts into `fm_id`. FileMaker's zc*/zg*/zs* calc, global and
# summary fields are imported too but left out here — nothing reads them.
#
#   RecordID              PK, e.g. D29186
#   RolodexID             FK → FmRolodex, the payer
#   OrgID                 FK → FmOrganization
#   ProjectID             FK → FmProject
#   ParticRecID           FK → FmParticipant.PRecID, redundant with FmParticipant.PaymentID
#   PledgeID              FK → FmPayment, pledge this payment pays down
#   FormSubmissionID      external ref, e.g. FSB03117
#   InvoiceID             external ref
#   RefID                 external ref
#   FormLetterID          acknowledgment letter
#   Name
#   Description
#   Note
#   Type
#   Category
#   Account
#   Year
#   Amount
#   Value                 in-kind value
#   Quantity
#   InKindValueAcknowl
#   PledgeSchedule
#   LetterStatus
#   PaymentMethod
#   PaymentDetails        card last 4 plus processor transaction ID
#   DateReceived
#   EnteredBy
#   ModifiedBy
#   DateEntered
#   ModificationDateTime
class FmPayment < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "RecordID"

  FM_LINKS = {
    "RolodexID" => "fm_rolodexes",
    "OrgID" => "fm_organizations",
    "ProjectID" => "fm_projects"
  }.freeze

  HAS_MANY = {
    "fm_activities" => { via: "LinkID", label: "Activities" },
    "fm_participants" => { via: "PaymentID", label: "Participants" }
  }.freeze
end
