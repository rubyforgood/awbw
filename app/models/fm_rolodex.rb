# Party table — every person and agency contact.
#
# FileMaker source: prj_RDX__Rolodex (Rolodex.csv, 39,608 rows).
# Fields below live in the `data` JSON column, except the primary key, which
# the import lifts into `fm_id`. FileMaker's zc*/zg*/zs* calc, global and
# summary fields are imported too but left out here — nothing reads them.
#
#   ID                        PK, e.g. 00006
#   OrgID                     FK → FmOrganization
#   PrimaryContactID          FK → FmRolodex
#   PrimaryAddrsID            FK → FmAddress
#   WorksiteAddrsID           FK → FmAddress
#   PrimaryPhoneID            FK → FmPhoneNumber
#   NamePrefix
#   FirstName
#   MiddleName
#   LastName
#   Suffix
#   Pronouns
#   Gender
#   Gender2ndPerson           second person on a shared record
#   Title
#   Department
#   Dept2ndName
#   Organization              denormalized org name
#   Classification
#   Status
#   isAgency__c               agency rather than individual
#   PrimaryContact
#   IncludeTitle
#   ListBy
#   AddresseeGreetingStyles   drives the letter salutation
#   SourceOfName
#   FamilyCode
#   Keywords
#   Interest
#   MailingList
#   Private
#   Delete                    soft-delete flag
#   DuplicateStatus
#   Comments
#   NameNote
#   Mission
#   WebSite
#   EMail
#   EmailPrimary
#   EmailType
#   EmailNotes
#   BestTimeToCall
#   Ethnicity
#   Languages
#   DateOfBirth
#   BirthDay
#   BirthMonth
#   BirthYear
#   BirthdayFlag
#   Anniversary
#   Children
#   FacilitatorSinceMonth
#   FacilitatorSinceYear
#   FacilitatorStatusPending
#   HowTrained
#   TrainingMotivation
#   LifeExperiences
#   PrimaryAgeGroup
#   PrimaryServiceArea
#   OtherServiceArea
#   BBSLicense                board of behavioral sciences license
#   VolEnrollDate
#   DropDate
#   AvailMon
#   AvailTue
#   AvailWed
#   AvailThu
#   AvailFri
#   AvailSat
#   Settings                  workshop settings the facilitator works in
#   Amount
#   CkNo                      check number
#   DonationCount
#   DonationTotal
#   FunderPotential
#   CallForArtRecord
#   UserID                    legacy FileMaker login
#   Password                  legacy FileMaker login
#   EnteredBy
#   ModifiedBy
#   DateEntered
#   DateTimeModified
class FmRolodex < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "ID"

  FM_LINKS = {
    "OrgID" => "fm_organizations",
    "PrimaryAddrsID" => "fm_addresses",
    "PrimaryPhoneID" => "fm_phone_numbers",
    "PrimaryContactID" => "fm_rolodexes",
    "WorksiteAddrsID" => "fm_addresses"
  }.freeze

  HAS_MANY = {
    "fm_addresses" => { via: "RolodexID", label: "Addresses" },
    "fm_phone_numbers" => { via: "RolodexID", label: "Phone Numbers" },
    "fm_payments" => { via: "RolodexID", label: "Payments" },
    "fm_activities" => { via: "ID", label: "Activities" },
    "fm_notes" => { via: "RolodexID", label: "Notes" },
    "fm_personnels" => { via: "PersonID", label: "Personnel" },
    "fm_workshop_logs" => { via: "LeaderID", label: "Workshop Logs" },
    "fm_participants" => { via: :fm_id, label: "Participations" },
    "fm_funding" => { via: "FunderID", label: "Funding" },
    "fm_program_sponsorships" => { via: "FunderID", label: "Program Sponsorships" }
  }.freeze
end
