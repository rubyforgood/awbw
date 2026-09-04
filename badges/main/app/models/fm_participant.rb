# Event registrations — one row per person per event.
#
# FileMaker source: prj_PTC__Participants (Participants.csv, 68,497 rows).
# Fields below live in the `data` JSON column, except the primary key, which
# the import lifts into `fm_id`. FileMaker's zc*/zg*/zs* calc, global and
# summary fields are imported too but left out here — nothing reads them.
#
# The PK is PRecID, not ParticipantID: ParticipantID identifies the registrant
# (it is their FmRolodex ID) and repeats across every event they attended, so
# keying on it collapsed each person to one row and silently dropped 47,084 of
# the 68,497 registrations against the unique fm_id index.
#
#   PRecID            PK
#   ParticipantID     FK → FmRolodex, the registrant
#   EventID           FK → FmEvent
#   ProjectID         FK → FmProject
#   OrgID             FK → FmOrganization
#   AllocRecID        FK → FmAllocation, scholarship funding the seat
#   PaymentID         FK → FmPayment
#   HostID            FK → FmRolodex, host who invited this guest
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
  FM_KEY_COLUMN = "PRecID"

  FM_LINKS = {
    "ParticipantID" => "fm_rolodexes",
    "EventID" => "fm_events",
    "OrgID" => "fm_organizations",
    "ProjectID" => "fm_projects",
    "AllocRecID" => "fm_allocations",
    "PaymentID" => "fm_payments",
    "HostID" => "fm_rolodexes"
  }.freeze

  HAS_MANY = {
    "fm_payments" => { via: "ParticRecID", label: "Payments" }
  }.freeze
end
