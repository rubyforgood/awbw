# Form submissions — completed registration and survey forms.
#
# FileMaker source: FormSubmissions (FormSubmissions.csv, 26,292 rows).
# Fields below live in the `data` JSON column, except the primary key, which
# the import lifts into `fm_id`. FileMaker's zc*/zg*/zs* calc, global and
# summary fields are imported too but left out here — nothing reads them.
#
#   RecordID              PK
#   EntryID
#   FormID                FK → FmFormsList
#   EventID               FK → FmEvent
#   OrgID                 FK → FmOrganization
#   RolodexID             FK → FmRolodex
#   ProjectID             FK → FmProject
#   PaymentID             FK → FmPayment
#   ParticRecID           FK → FmParticipant (uses P prefix format, e.g. P52646,
#                         differs from canonical bare-numeric ParticipantID)
#   PersonnelID           FK → FmPersonnel (uses PS prefix, e.g. PS10005,
#                         differs from Personnel's own bare-numeric PrsnlRecID)
#   FormTitle
#   FormType
#   EntryStatusWP
#   FirstName
#   LastName
#   EmailPrimary
#   EmailSecondary
#   Phone
#   OrgName
#   Status
#   NeedScholarship
#   Settings
#   LifeExperiences
#   PrimaryAgeGroup
#   PrimaryServiceArea
#   PaymentMethod
#   PaymentAmount
#   PaymentDate
#   PaymentStatus
#   Notes
#   EnteredBy
#   ModifiedBy
#   EntryDate
#   ModificationTimeStamp
class FmFormSubmission < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "RecordID"

  FM_LINKS = {
    "FormID" => "fm_forms_lists",
    "EventID" => "fm_events",
    "OrgID" => "fm_organizations",
    "RolodexID" => "fm_rolodexes",
    "ProjectID" => "fm_projects",
    "PaymentID" => "fm_payments",
    "ParticRecID" => "fm_participants"
  }.freeze
end
