# Party table — every person and agency contact.
#
# FileMaker source: prj_RDX__Rolodex (Rolodex.csv, 39,608 rows).
# Fields below live in the `data` JSON column, except the primary key, which
# the import lifts into `fm_id`. FileMaker's zc*/zg*/zs* calc, global and
# summary fields are imported too but left out here — nothing reads them.
#
#   ID                        PK, e.g. 00006
#   OrgID                     FK → FmOrganization (7 rows contain professional
#                               credentials like BSW, LCSW-C instead of ORG IDs
#                               — data-entry errors)
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
#   EmailPrimary              which slot EMail is: 1 primary, 2 secondary
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

  PHONES = "Phones"
  ADDRESSES = "Addresses"
  JOB_AFFILIATION = "Job affiliation"
  FACILITATOR_AFFILIATION = "Facilitator affiliation"
  LISTED_FIELDS = %w[PrimaryPhoneID PrimaryAddrsID WorksiteAddrsID].freeze
  TALL_GROUPS = [ "Organization & affiliations" ].freeze
  PORTAL_FIELDS = {
    "FirstName" => "people.first_name",
    "LastName" => "people.last_name",
    "Pronouns" => "people.pronouns",
    "EmailPrimary" => "people.email or people.email_2 (the slot EMail lands in)",
    "EMail" => "people.email",
    "EmailType" => "people.email_type",
    "BestTimeToCall" => "people.best_time_to_call",
    "DateOfBirth" => "people.date_of_birth",
    "Ethnicity" => "people.racial_ethnic_identity",
    "Title" => "affiliations.title",
    "FacilitatorSinceMonth" => "people.member_since (with FacilitatorSinceYear)",
    "FacilitatorSinceYear" => "people.member_since (with FacilitatorSinceMonth)",
    "PrimaryServiceArea" => "the person's primary sector",
    "OtherServiceArea" => "the person's additional sectors",
    "Settings" => "the person's additional sectors",
    "LifeExperiences" => "the person's additional sectors",
    "PrimaryAgeGroup" => "the person's primary age group",
    "DateEntered" => "people.created_at",
    "DateTimeModified" => "people.updated_at",
    "EnteredBy" => "people.created_by_id",
    "ModifiedBy" => "people.updated_by_id"
  }.freeze
  USER_LOOKUP_FIELDS = %w[EnteredBy ModifiedBy].freeze

  PORTAL_COUNTERPARTS = {
    "fm_addresses" => "Addresses",
    "fm_phone_numbers" => "Contact methods",
    "fm_notes" => "Comments",
    "fm_activities" => "Communications",
    "fm_people_to_organizations" => "Affiliations",
    "fm_personnels" => "Affiliations",
    "fm_workshop_logs" => "Workshop logs",
    "fm_workshops" => "Workshops",
    "fm_participants" => "Event registrations",
    "fm_payments" => "Payments",
    "fm_fundings" => "Scholarships",
    "fm_invoices" => "Invoices",
    "fm_quotations" => "Quotes"
  }.freeze

  FIELD_GROUPS = {
    "Identity" => %w[NamePrefix FirstName MiddleName LastName Suffix Pronouns Gender Gender2ndPerson isAgency__c
                     EMail EmailPrimary EmailType EmailNotes BestTimeToCall],
    "Phones & addresses" => {
      PHONES => %w[PrimaryPhoneID],
      ADDRESSES => %w[PrimaryAddrsID WorksiteAddrsID],
      "Mailing list" => %w[MailingList]
    },
    "Organization & affiliations" => {
      "Classification & status" => %w[Classification Status],
      "Organization" => %w[Organization OrgID WebSite Mission PrimaryContact PrimaryContactID],
      JOB_AFFILIATION => %w[Title Department Dept2ndName],
      FACILITATOR_AFFILIATION => %w[FacilitatorSinceMonth FacilitatorSinceYear FacilitatorStatusPending
                                    HowTrained TrainingMotivation LifeExperiences Settings BBSLicense]
    },
    "Sector & age group" => %w[PrimaryServiceArea OtherServiceArea PrimaryAgeGroup],
    "Record keeping" => %w[ID Delete DuplicateStatus EnteredBy DateEntered ModifiedBy DateTimeModified UserID Password],
    "Notes" => %w[Comments NameNote Keywords Interest SourceOfName],
    "Volunteering" => %w[VolEnrollDate DropDate AvailMon AvailTue AvailWed AvailThu AvailFri AvailSat],
    "Giving" => %w[DonationCount DonationTotal Amount CkNo FunderPotential CallForArtRecord],
    "Personal details" => %w[DateOfBirth BirthMonth BirthDay BirthYear BirthdayFlag Anniversary Children
                             Ethnicity Languages],
    "Mailing" => %w[AddresseeGreetingStyles ListBy IncludeTitle FamilyCode Private]
  }.freeze

  HAS_MANY = {
    "fm_addresses" => { via: "RolodexID", label: "Addresses" },
    "fm_phone_numbers" => { via: "RolodexID", label: "Phone Numbers" },
    "fm_contacts" => { via: "ContacteeID", label: "Contacts", note: "Data from 2003–2018" },
    "fm_notes" => { via: "RolodexID", label: "Notes" },
    "fm_activities" => { via: "ID", label: "Activities", note: "Data from 2003–2025" },
    "fm_form_letters" => { via: "SignatureID", label: "Form Letters (Signed)" },
    "fm_people_to_organizations" => { via: "PersonID", label: "Org Affiliations" },
    "fm_personnels" => { via: "PersonID", label: "Personnel" },
    "fm_committee_members" => { via: "MemberID", label: "Committee Memberships" },
    "fm_group_members" => { via: "ContactID", label: "Group Memberships" },
    "fm_workshop_logs" => { via: "LeaderID", label: "Workshop Logs" },
    "fm_workshops" => { via: "AuthorID", label: "Workshops Authored" },
    "fm_participants" => { via: "ParticipantID", label: "Participations" },
    "fm_volunteers" => { via: "VRecID", label: "Volunteer Records" },
    "fm_payments" => { via: "RolodexID", label: "Payments" },
    "fm_invoices" => { via: "RolodexID", label: "Invoices" },
    "fm_fundings" => { via: "FunderID", label: "Funding" },
    "fm_program_sponsorships" => { via: "FunderID", label: "Program Sponsorships" },
    "fm_solicitations" => { via: "DonorID", label: "Solicitations" },
    "fm_donor_developers" => { via: "RolodexID", label: "Donor Developments" },
    "fm_quotations" => { via: "RolodexID", label: "Quotations" },
    "fm_art_registries" => { via: "ArtistID", label: "Art Registries (Artist)" },
    "fm_ancillary_data" => { via: "RolodexID", label: "Ancillary Data" }
  }.freeze

  def name
    agency = fm_value("Organization")
    fm_join("FirstName", "LastName") || (agency && "#{agency} (agency)") || fm_id
  end

  # Every record of `model` keyed by fm_id and grouped by the RolodexID it names, for a bulk
  # reader to hand to #preload_contacts so each row reads from memory.
  def self.contact_index(model)
    records = model.all.to_a
    { by_id: records.index_by(&:fm_id), by_rolodex: records.group_by { |record| record.data["RolodexID"].to_s } }
  end

  def preload_contacts(addresses:, phone_numbers:)
    @addresses = contact_records(FmAddress, primary_ids: address_ids, index: addresses)
    @phone_numbers = contact_records(FmPhoneNumber, primary_ids: phone_ids, index: phone_numbers)
    self
  end

  def phone_numbers
    @phone_numbers ||= contact_records(FmPhoneNumber, primary_ids: phone_ids)
  end

  def addresses
    @addresses ||= contact_records(FmAddress, primary_ids: address_ids)
  end

  def job_affiliations
    @job_affiliations ||= FmPeopleToOrganization.find_by_data("PersonID", fm_id).order(:fm_id).to_a
  end

  def facilitator_affiliations
    @facilitator_affiliations ||= FmPersonnel.find_by_data("PersonID", fm_id).order(:fm_id).to_a
  end

  def records_listed_under(label)
    case label
    when PHONES then phone_numbers
    when ADDRESSES then addresses
    when JOB_AFFILIATION then job_affiliations
    when FACILITATOR_AFFILIATION then facilitator_affiliations
    else []
    end
  end

  private

  def phone_ids = data.values_at("PrimaryPhoneID")
  def address_ids = data.values_at("PrimaryAddrsID", "WorksiteAddrsID")

  # Ones this record points at are listed first, even when their RolodexID names someone else; one the
  # archive lacks stands in as an unsaved placeholder.
  def contact_records(model, primary_ids:, index: nil)
    primary_ids = primary_ids.compact_blank.uniq
    records = if index
      (index[:by_rolodex].fetch(fm_id, []) + primary_ids.filter_map { |id| index[:by_id][id] }).uniq.sort_by(&:fm_id)
    else
      model.find_by_data("RolodexID", fm_id).or(model.where(fm_id: primary_ids)).order(:fm_id).to_a
    end
    records += (primary_ids - records.map(&:fm_id)).map { |id| model.new(fm_id: id, data: {}) }
    records.sort_by { |record| primary_ids.index(record.fm_id) || primary_ids.size }
  end
end
