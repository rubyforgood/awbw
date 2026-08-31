# Event registrations. ParticipantID doubles as the registrant's rolodex ID.
#
# FileMaker source: prj_PTC__Participants (Participants.csv, 68,497 rows).
# Fields below live in the `data` JSON column, except the primary key, which
# the import lifts into `fm_id`. FileMaker's zc*/zg*/zs* calc, global and
# summary fields are imported too but left out here — nothing reads them.
#
#   ParticipantID     PK, also the FmRolodex ID of the registrant
#   EventID           FK → FmEvent
#   ProjectID         FK → FmProject
#   OrgID             FK → FmOrganization
#   AllocRecID        FK → FmAllocation, scholarship funding the seat
#   PaymentID         FK → FmPayment
#   HostID            FK → FmRolodex, host who invited this guest
#   PRecID            legacy participant ref, unlinked in the UI
#   SubmissionID      external ref
#   Name
#   Organization      denormalized
#   Phone
#   Role
#   Status
#   Year
#   Invited
#   Replied
#   Attended
#   Paid
#   Comp              comped seat
#   NoOfPersons
#   Fee
#   AmountPaid
#   BidderNumbers     silent auction
#   CEHours           continuing education hours
#   Notes
#   Comments
#   EnteredBy
#   ModifiedBy
#   DateEntered
#   DateTimeModified
class FmParticipant < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "ParticipantID"

  FM_LINKS = {
    "EventID" => "fm_events",
    "OrgID" => "fm_organizations",
    "ProjectID" => "fm_projects",
    "AllocRecID" => "fm_allocations",
    "PaymentID" => "fm_payments",
    "HostID" => "fm_rolodexes"
  }.freeze

  HAS_MANY = {
    "fm_rolodexes" => { via: :fm_id, label: "Rolodex" }
  }.freeze
end
