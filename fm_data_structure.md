# FileMaker Data Structure via ODBC API

## Complete Table Inventory

Source: http://127.0.0.1:5000/tables (111 tables total)

### Core Data Tables (unique datasets)

Tables are listed with their `prj_` prefix variants (the main context). Prefix variants (`exp_`, `prs_`, `srv_`, `wsl_`, etc.) point to the same underlying data.

| # | Table Name | Row Count | Description |
|---|-----------|-----------|-------------|
| 1 | `prj_RDX__Rolodex` | **39,608** | Master contact list (people/individuals) |
| 2 | `prj_ORG__Organization` | **7,191** | Organizations/Agencies |
| 3 | `PRJ__Projects` | **1,976** | Programs/Projects |
| 4 | `prj_SRV__Service` | **69,590** | Monthly service records (workshop counts by project) |
| 5 | `WORKSHOPLOG` (also `WSL__WorkshopLog`) | **10,859** | Individual workshop log entries |
| 6 | `prj_PRS__Personnel` | **8,907** | Personnel assignment (people linked to projects) |
| 7 | `prj_ALC__Allocations` | **3,099** | Funding allocations from grants to projects |
| 8 | `prj_PMT__Payment` | **27,146** | Donations and payments |
| 9 | `prj_NTS__Notes` | **616** | Notes/annotations |
| 10 | `prj_EXP__Expenditure` | **5,314** | Expenditures |
| 11 | `prj_PTC__Participants` | **68,497** | Event participants (registrations) |
| 12 | `prj_org_ADR__Addresses` | **28,398** | Organization addresses |
| 13 | `prj_prs_ADR__Addresses` | **28,398** | Personnel addresses |
| 14 | `prj_org_PHN__Phones` | **33,915** | Organization phone numbers |
| 15 | `prj_FND__FundingviaTempID` | **1,391** | Funding sources/grants |
| 16 | `prj_PSP__ProgramSponsorships` | **608** | Program sponsorships |
| 17 | `prj_PZC__CityState` | **80,134** | City/State/ZIP lookup table |
| 18 | `prj_EVT__Events` | **3,468** | Events |
| 19 | `prj_psp_FND__Funding` | (1,391) | Alias for funding (same data as prj_FND__FundingviaTempID) |
| - | `SERVICE`, `SRV__Service` | (69,590) | Alias for prj_SRV__Service |
| - | `PRS__Personnel` | (8,907) | Alias for prj_PRS__Personnel |
| - | `EXP__Expenditure` | (5,314) | Alias for prj_EXP__Expenditure |

### Tables Excluded (Utility/View/Relationship tables)

Contains "Via", "CreateSelect", "MarkedRecords", "Merge", "MMU__", "UIF__", "VTL__", "UserInterface", "CurrentRecord", "VirtualList":

- All `*_MMU__*` tables (menu navigation)
- All `*_UIF__*` / `uif_*` tables (User Interface Framework)
- All `*_VTL__*` / `vtl_*` tables (Virtual List)
- All `*Via*` tables (FileMaker relationship contexts)
- `*CreateSelect`, `*MarkedRecords`, `*Merge*`, `*CurrentRecord`, `*VirtualList`
- `RDXUserInterface`, `UIF__UserInterface`
- Various `*Key`, `*By*` relationship join tables

---

## Column Schemas

### 1. prj_RDX__Rolodex (39,608 rows)
Master contact/rolodex for all individuals (facilitators, contacts, participants, staff).

Key columns: `ID` (primary key, e.g. "00006"), `FirstName`, `LastName`, `Organization`, `Department`, `Title`, `EMail`, `Gender`, `Ethnicity`, `Languages`, `Classification`, `Status`, `PrimaryAddrsID`, `PrimaryPhoneID`, `OrgID`, `UserID`, `DateEntered`, `DateTimeModified`, `zcFullName`, `zcPrimaryEmailAddrs`, `zcPrimaryPhoneNo`, `zcPrimaryAddressID`

Full columns (182): FirstName, LastName, zcCategory, DateEntered, SourceOfName, zcFullName, Department, Organization, DateTimeModified, Delete, Gender, EMail, ListBy, zcListing, ID, Dept2ndName, zcNameOrgPlusID, NamePrefix, MiddleName, AddresseeGreetingStyles, zcAddressee, zcGreeting, zcDeptTitleAddrsLine, zcOrgAddrsLine, Comments, Gender2ndPerson, zcTwoPersonCalc, MailingList, zsCountID, Private, zgSearchName, Keywords, zcSecPersLastFirstName, zcReturnCheckCompany, Classification, Suffix, WebSite, EnteredBy, ModifiedBy, zcFullNamePlusCompany, zcCountActivities, zcConstantKey, zcMark, zcMatchName, FamilyCode, BirthMonth, Children, DateOfBirth, Anniversary, zcPrimaryEmailAddrs, zgContactLogID, Title, PrimaryContact, zcOrgCount, zcMultiValueKey, zgFilterSelection, zcFilterKey, zgFilter, zcCountFilteredRecords, zgCurrentRecordID, zgHiliteGraphic, zcCurrentRecordIndicator, zcPortalLabel, zgCurrentPortalRow, zcListingAlpha, zcDeptLabel, zgAddressGraphic, Interest, VolEnrollDate, zgCounter, zgProjectID, zcEnrollmentCount, zcAddresseeTest, zcListingWithTitle, zcHome, zcWork, zcComSp2, zcOrgNameAlpha, zcCountProjects, zgLastLayout, zcRecordsFound, zcMode, zcTotalRecords, zcAssignmentCount, zcVolID, zcVolName, zcProjectID, PrimaryContactID, Ethnicity, Languages, AvailMon, AvailTue, AvailWed, AvailThu, AvailFri, AvailSat, EmailType, zcDuplNameKey, zcDuplPossKey, zcDuplYesKey, zcDuplFlag, zcDuplMultiKey, zcDuplOrigFlag, zcCountPossDupl, zcLinked, DuplicateStatus, zgCurrentID, zcFullNamePlusDept, zcOrgIDKey, zgTempHolder, zcEmailKey, zgTempID, zsMarkedFlaggedRecords, Amount, CallForArtRecord, PrimaryServiceArea, CkNo, Settings, LifeExperiences, PrimaryAgeGroup, NameNote, FacilitatorSinceYear, DonationCount, Pronouns, DonationTotal, UnusedNumberField, FacilitatorSinceMonth, zgFacilitatorSince, zgActive, PrimaryPhoneID, zgGroupActive, zgTransCategory, zcCountArtRegistryAsBuyer, zcCountArtRegistryAsArtist, zcCountArtPurchases, zcCountContacts, zcCountEvents, zcPrimaryEmailType, HowTrained, zgReportTitle, zgFormLetterID, Status, zcCountRelatedPersonnel, zgProgTypeSelector, zcPersonnelKey, IncludeTitle, zgStatusCode, zgContactLink, zgFileInitialized, zcCountMarkedFlaggedRecords, zgMarkedRecords, zgPRecID, zgTempText, zgDonationYearsSelected, zcLastContact, zgCIDBtn, zcCIDBtn, zgFileName, zgYear, zcLastEvent, zgClassification, zcClassification, zcAuditTrigger, zcModifiedByUserName, DropDate, zcLastDropDate, zgFlagMark, zcFlMkLabel, zgTempDate, zgEventYearsSelected, zcEventYearsID, zcCountEventsByYear, zgVolYearsSelected, zcVolYearsID, zcCountVolByYear, zcTotalVolHours, BirthDay, BirthYear, BirthdayFlag, zgPages, BestTimeToCall, Password, UserID, zgTempNo, zgEventID, zgCurrentYear, zgPreviousYear, zgGivingLevel, zgComparisonAmount, zgComparisonSelector, FunderPotential, zgFunderPotential, zgFundingPotential, zgProgSponStatus, zgSidebar, zgSidebarDocID, zgGreetingGeneric, zgGroupType, zgGroupID, zcGroupMember, zgDateBegin, zgDateEnd, zcTotalVolHrsByDate, BBSLicense, zcCEHours, Mission, OrgID, zcEmailAddresses, _kf_sqlUser_ID, isAgency__c, EmailNotes, EmailPrimary, zcEmailAddrsCount, zgNoteID, zcNotesInfo, FacilitatorStatusPending, zcCountPersonalPhones, zcFirstLastName, zgFormSubmissionID, zcPrimaryPhoneID, zgGroupCategory, zgCurrentLayout, zgPaymentCategory, zcCountPayments, zcTotalPayments, zcPrimaryPhoneNo, PrimaryAddrsID, WorksiteAddrsID, zcPrimaryAddressID, zcPrimaryAddressCategory, zcCountDuplNames, TrainingMotivation, OtherServiceArea, zcPrimaryServiceArea

### 2. prj_ORG__Organization (7,191 rows)
Organizations/agencies.

Key columns: `OrgID`, `OrgName`, `OrgType`, `Classification`, `Status`, `Website`, `ParentID` (hierarchical), `Mission`, `MainID`

Full columns (42): OrgID, OrgName, OrgType, Comments, zgOrgID, zgSubmissionID, zcConstant, zcCategory, Description, Facilities, zgMarkedRecords, zcMarked, zcCountMarked, zsRecordCount, zsMarkedRecords, FundingPriorities, Interests, Meetings, Newsletter, Classification, CreatedBy, CreationDate, ModificationDateTime, ModifiedBy, zgOrgName, zgTempID, zcFlagged, zaChangeLog, MainID, zgRole, zgYear, Keywords, Website, zcCountContacts, Status, zcProjectCount, Hierarchy, ParentID, zcChildRecordIDs, Mission, OutreachStatus, OutreachDate, zgNoteID, zcNotesInfo, zgActive

### 3. PRJ__Projects (1,976 rows)
Programs/projects at organizations.

Key columns: `ProjectID`, `FacilityID`, `ProjectName`, `ProjectType`, `Status`, `StartDate`, `EndDate`, `OrgID`, `Locality`, `City`, `County`, `State`, `Primary`, `ObligationStatus`, `Comments`

Full columns (117): ProjectID, FacilityID, ProjectName, ProjectType, Description, Status, StartDate, DateEntered, zcProjectName, zgHiliteGraphic, zcCurrentRecordIndicator, zgInfoGraphic, zcInfo, zgCurrentRecordID, zgDeletionGraphic, zcLastNameFirstName, zcConstantKey, zcRecordsFound, DateTimeModified, zgCurrentProjectID, zgFacilityIDs, zcMark, Comments, EnteredBy, ModifiedBy, EndDate, Locality, zgYearSelector, zcProjectYearKey, zcYrTotalOngoing, zcYrTotalNew, zcYrTotal, zcTotalAllocGenl, zcTotalAllocSupl, zcTotalAllocation, zcTotalAllocTrainings, zcTotalExpend, zcExpendBalance, zgTab1, zgTab2, zgTab3, zgTab4, zgTab5, zgTab6, zgTab7, zgMonthSelector, zcProjectYearMonthKey, zcReportStatus, zcMonthNoSelected, zgPersonnelStatusSelector, zgRolodexContactSelector, zcPersonnelKey, zcRolodexKey, zcLeaderKey, zcLiaisonKey, zcAssistantKey, zcCoLeaderKey, zgStaffListKey, zcReportStatusCopy, zcTest, zgTempID, zcLiaisonName, zgFileInitialized, zcRemainingTrainings, zcTrainingsUsed, ObligationStatus, zcReportCount, zcMissingReportCount, zgTempText, zgMarkedRecords, zcCountMarkedRecords, zsMarkedRecords, District, zgBtn1, zgBtn2, zgBtn3, zgBtn4, zgBtn5, zgBtn6, zgBtn7, zgBtn8, zgFileName, zgLastLayout, zgTempHolder, zcProjActive, WebID, zgTempNo, FundingPotential, zgFundingPotential, zgFunderPotential, zgQuotationFlagsSelector, zcCountQuotations, zcCountProgSponsorships, zgProgSponsStatus, zgActive, zgExpendCategory, zgExpendType, zcTotalAllocExhib, zgStartDate, zgEndDate, QuotationID, MessageText, zcRelatedEventIDs, zcYrTotalNewAdult, zcYrTotalNewTeen, zcYrTotalNewChild, zcYrTotalOngoingAdult, zcYrTotalOngoingTeen, zcYrTotalOngoingChild, CreatedBy, OrgID, Primary, MergerWithID, SQLid, PrimarySetting, SecondarySetting, PrimaryServiceArea, CloseDate, LASupervisorialDistrict, International, SPA, FeePaidFor, zcCountPersonnel, State, SecondaryAreas, County, City, zcSummaryInfo, zcProjectNameStatus, LifeExperiences, zgNoteID, zcNotesInfo, AgencyType

### 4. prj_EVT__Events (3,468 rows)
Events (trainings, fundraisers, etc.).

Key columns: `EventID`, `Title`, `Category`, `Description`, `Fee`, `EventDate`, `EndDate`, `StartTime`, `EndTime`, `Location`, `Organizer`, `Year`, `MinParticipants`, `MaxParticipants`

Full columns (108): Title, Category, Description, Notes, Fee, EventDate, EndDate, Organizer, Location, StartTime, EndTime, MinParticipants, MaxParticipants, EventID, zgCurrentYear, zgCurrentTerm, zgCounter, Year, Group, zcLocationCode, zgHiliteGraphic, DateEntered, DateTimeModified, ModifiedBy, zcStartDay, zgCurrentRecordID, zcCurrentRecordIndicator, zgCurrentEventID, zcCountParticipants, Available, zcAvailableEventID, zcAvailableEventTitleDate, zcEventIDLeadKey, zgAddGraphic, zcAddVolunteerGraphic, zcConstantKey, zcRecordsFound, zgTab1, zgTab2, zgTab3, zgTab4, zgTab5, zgTab6, zgTab7, zgLastLayout, zgTempHolder, zcEventTitleDate, zcTotalPaid, zcTotalRegistered, zgPRecID, zgMarkedRecords, zgTempText, zcMark, zcCountMarkedRecords, zsMarkedRecords, zgFileInitialized, zcCountVolunteers, zcHostKey, zcNonHostKey, zcHostDonationKey, zcNonHostDonationKey, zcNonAttendingDonationKey, zcSilentAuctionKey, zcCountHosts, zcCountNonHosts, zcCountNonAttendDonations, zcTotalHostDonations, zcTotalNonHostDonations, zcTotalNonAttendDonations, zcTotalSilentAuctionDonations, zcTotalAttendees, zcTotalReplied, zcTotalRaised, zcCountSilentAuctionDonations, zcTotalAttending, EventCostItems, EventCosts, zcTotalEventCost, EventCostsInKind, zcTotalEventCostInKind, zgBtn1, zgBtn2, zgBtn3, zgBtn4, zgBtn5, zgBtn6, zgBtn7, zgBtn8, zgFileName, EnteredBy, EstimatedParticipants, zcAvailableEventTitle, zgRolodexID, zgProjectID, zgTempID, zgConstant, zgRole, Comments, zcHostGuestKey, LinkID, zsRecordCount, zcParticipantIDs, zgParticipantStatus, zcStatusTotals, zcCountParticipantsByStatus, zcParticipantStatus, zcTotalAttendingByStatus, ItemDescription, Type

### 5. prj_SRV__Service (69,590 rows)
Monthly service records — workshop attendance counts by project/month/year.

Key columns: `RecordID`, `ProjectID`, `Month`, `Year`, `NewAdult`, `OngoingAdult`, `NewTeen`, `OngoingTeen`, `NewChild`, `OngoingChild`, `zcTotalServed`, `Acknowledgment`, `LateCard`, `zcSubmitted`

Full columns (131): RecordID, ProjectID, Month, Year, NewAdult, OngoingAdult, zcMonthYear, zcProjectYearKey, zcTotalServed, zgMonths, zcOngoing01, zcOngoing02, zcOngoing03, zcOngoing04, zcOngoing05, zcOngoing06, zcOngoing07, zcOngoing08, zcOngoing09, zcOngoing10, zcOngoing11, zcOngoing12, zcNew01, zcNew02, zcNew03, zcNew04, zcNew05, zcNew06, zcNew07, zcNew08, zcNew09, zcNew10, zcNew11, zcNew12, zcTotal01, zcTotal02, zcTotal03, zcTotal04, zcTotal05, zcTotal06, zcTotal07, zcTotal08, zcTotal09, zcTotal10, zcTotal11, zsTotalOngoing01, zsTotalOngoing02, zsTotalOngoing03, zsTotalOngoing04, zsTotalOngoing05, zsTotalOngoing06, zsTotalOngoing07, zsTotalOngoing08, zsTotalOngoing09, zsTotalOngoing10, zsTotalOngoing11, zsTotalOngoing12, zsTotalNew01, zsTotalNew02, zsTotalNew03, zsTotalNew04, zsTotalNew05, zsTotalNew06, zsTotalNew07, zsTotalNew08, zsTotalNew09, zsTotalNew10, zsTotalNew11, zsTotalNew12, zsTotal01, zsTotal02, zsTotal03, zsTotal04, zsTotal05, zsTotal06, zsTotal07, zsTotal08, zsTotal09, zsTotal10, zsTotal11, zsTotal12, zcTotal12, zgYearSelector, zcProjYrMoKey, zcDuplWarning, zcConstantKey, zgProjectID, zgYear, zcProjectNameID, zcProjectYear, zcTotalProjYrOngoing, zcTotalProjYrNew, zcTotalProjYrTotal, zsTotalOngoing, zsTotalNew, zsTotalServed, zcMonthNo, zgHeaderTitle, zgHeaderLogo, zgHeaderIcon, zgFilename, zcRecordsFound, zgFileInitialized, zgHeaderIcon2, Acknowledgment, LateCard, zcSubmitted, zcProjectType, zgProjectTypeSelector, zsProjectCount, zcProjectLocalityKey, zcActiveProjByType, zcActiveProjByLocality, zcProjectObligStatus, zcActiveProjByOblStatus, zgReportTitle, zcProjYearCount, zsProjYearCount, OngoingTeen, OngoingChild, NewTeen, NewChild, zgAgeGroup, DateTimeCreated, CreatedBy, zcNew, zcOngoing, zsTotalNewAdult, zsTotalNewChild, zsTotalNewTeen, zsTotalOngoingAdult, zsTotalOngoingChild, zsTotalOngoingTeen, zcTotalAdult, zcTotalChild, zcTotalTeen, zsTotalAdult, zsTotalChild, zsTotalTeen, DateTimeModified, ModifiedBy

### 6. WORKSHOPLOG / WSL__WorkshopLog (10,859 rows)
Individual workshop log submissions.

Key columns: `RecordID`, `ProjectID`, `WorkshopDate`, `WorkshopTitle`, `LeaderID`, `LeaderName`, `WorkshopID`, `TotalNew`, `TotalOngoing`, `TotalNewChild`, `TotalOngoingChild`, `TotalNewTeen`, `TotalOngoingTeen`, `Materials`, `Notes`, `AgesAdult`, `AgesChild`, `AgesTeen`, `AgencyID`, `ReportDate`, `EnteredBy`, `MonthNumber__c`, `Year__c`, `sqlWorkshopID`

Full columns (67): RecordID, C02, TotalOngoing, Materials, TotalNew, zsCountRec, WorkshopTitle, zcConstant, zgYear, zgHeaderTitle, zgHeaderLogo, zgHeaderIcon, zgFileInitialized, zcRecordsFound, AgesAdult, zzz_DELETE_AgesNew, C01, zgFilename, zcConstant1, DateEntered, zgMarkedRecords, zcMark, zcCountMarkedRecords, zsMarkedRecords, zgQuestionSelector, zcSelectedQuestionResponse, zgTempText, Notes, WorkshopDate, ProjectID, LeaderID, LeaderName, WorkshopID, zgC01Label, zgC02Label, zgT01Label, zgT02Label, zgT03Label, zgCurrentRecordID, zcMonth, zcYear, zgMonthSelector, zgProjectIDSelector, zcCommentsText, zgWorkshopID, zgProjectID, zgPersonID, zcSummaryField, zcProjectName, zgTempID, LinkIDs, zgSummaryField, ReportSubmissionID, zgTempHolder, zcDateProjectWkshop, EnteredBy, ReportDate, WebReportID, TotalOngoingChild, TotalNewChild, AgesChild, zzz_DELETE_AgesOngoingChild, g_Date, zz_TimestampCreated, AgencyID, zcAgencyName, TotalNewTeen, TotalOngoingTeen, AgesTeen, MonthNumber__c, Year__c, sqlWorkshopID

### 7. prj_PRS__Personnel (8,907 rows)
Personnel assignments — links people to projects with roles.

Key columns: `PrsnlRecID`, `PersonID`, `ProjectID`, `Name`, `Role`, `Status`, `ProjectType`, `AgmtID`, `AgreementStatus`, `Update`, `Notes`

Full columns (45): PersonID, ProjectID, Name, ProjectType, Notes, zcLastFirstName, zcProjectName, zgHiliteGraphic, zgCurrentRecordID, zcCurrentRecordIndicator, zgDeletionGraphic, DateEntered, zcLastName, zcRecordsFound, zcConstantKey, Status, zgPersonIDs, zcLastFirstNameID, zsProjectCount, Update, UnusedNum1, zcRoloViaNameID, zgTempHolder, zcPrsnlIDProjectID, zcProjStartDate, PrsnlRecID, AgmtID, Role, zgPRecID, zcPersonnelKey, zcPrimaryPhone, zcMailing Address, zcMailing CityStateZip, zcBusinessPhone, zcHomePhone, zcEmail, zcUpdate, zgFileInitialized, zgFileName, zcBestTimeToCall, zgTempNo, DateTimeModified, AgreementStatus, EnteredBy, ModifiedBy

### 8. prj_ALC__Allocations (3,099 rows)
Funding allocations from grants to projects.

Key columns: `FundingRecID`, `AllocRecID`, `ProjectID`, `Year`, `AmountGeneral`, `AmountSupplies`, `AmountExhibit`, `Trainings`, `Status`, `Notes`, `zcFunderName`, `zcAmountTotal`

Full columns (37): FundingRecID, ProjectID, zcFunderName, Trainings, Notes, zcLastFirstName, zcProjectName, Year, zcCategory, zgHiliteGraphic, zgCurrentRecordID, zcCurrentRecordIndicator, zgDeletionGraphic, DateEntered, zcLastName, zcRecordsFound, zcConstantKey, Status, zgParticipantIDs, zcLastFirstNameID, AmountGeneral, AmountSupplies, Attended, Paid, zgTempHolder, zcParticipantIDEventID, AllocRecID, zcAmountTotal, zcProjectStartDate, Active, zcTrainingsUsed, zcRemainingTrainings, zcGrantCode, zcTrainingAmount, zcActiveTraining, zgFileInitialized, zgFileName, AmountExhibit

### 9. prj_PMT__Payment (27,146 rows)
Donations and payments received.

Key columns: `RecordID`, `RolodexID`, `DateReceived`, `Amount`, `Type`, `Category`, `Name`, `Description`, `PaymentMethod`, `PaymentDetails`, `OrgID`, `ProjectID`, `RefID`, `InvoiceID`, `PledgeID`

Full columns (70+): RolodexID, RecordID, DateReceived, Amount, Note, Name, zgInfoGraphic, zcConstantKey, zcRecordsFound, Type, ModificationDateTime, EnteredBy, Description, RefID, zcRolodexIDRefID, Quantity, zgTab1, zgTab2, zgTab3, zgTab4, LetterStatus, DateEntered, zcFormLetterID, zcFormLetterText, zcLetterCount, zsTotalLetterCount, zgCurrentDonationID, zgCurrentActivityLogID, Value, zgStartDate, zgEndDate, zsTotalAmount, zsTotalValue, zsRecordCount, zgDateRange, zcCatDateKey, InKindValueAcknowl, zgFileInitialized, PledgeID, zcPledgeDonationTotal, zcPledgeDonationBal, zcPledgeDonationLink, zgTempID, PledgeSchedule, zgMarkedRecords, zcMark, zgTempText, zcCountMarkedRecords, zsMarkedRecords, zgBtn1, zgBtn2, zgBtn3, zgBtn4, zgBtn5, zgBtn6, zgBtn7, zgBtn8, zgLastLayout, zgFileName, zcCompanyName, zcOrganizationName, ParticRecID, zcRefTypeKey, zcEventHostName, FormLetterID, zcTotalByDonor, zcYear, zcAmtValue, zcInfoGraphic, zcDonorListingAlpha, zgMatching, zgFundingID, ModifiedBy, Category, OrgID, ProjectID, FormSubmissionID, PaymentMethod, PaymentDetails, Account, Year, InvoiceID, zcCountRelatedParticipants, zcTotalParticipantsAmountPaid, zcTotalParticipantsBalanceDue

### 10. prj_NTS__Notes (616 rows)
Notes/annotations linked to records.

Key columns: `NoteID`, `Date`, `Subject`, `Category`, `Status`, `Classification`, `Note`, `RolodexID`, `OrgID`, `ProjectID`, `EventID`, `LinkID`, `EnteredBy`, `ModifiedBy`, `DateTimeModified`

Full columns (40): NoteID, Date, Subject, Category, Status, Classification, zgClassification, zcFlagged, Context, zsFlaggedRecords, zcConstant, zcCategoryCount, zgLastLayout, zgTempHolder, zgMarkedRecords, zcMarked, zgTempText, zgTempID, zcCountMarkedRecords, zsMarkedRecords, zgReportTitle, zsCount, zgCurrentRecordID, Note, DateTimeModified, RolodexID, zgZoom, zgCategory, zcCountRelCat, zgSortField, zcSortField, zcCategories, LinkID, EnteredBy, OrgID, ProjectID, EventID, zcSubject, ModifiedBy, zcNoteInfo

### 11. prj_EXP__Expenditure (5,314 rows)
Expenditures against projects.

Key columns: `ExpendRecID`, `ProjectID`, `Type`, `Category`, `Amount`, `CheckNo`, `DatePaid`, `Description`, `Name`, `Notes`, `DateEntered`

Full columns (24): ProjectID, Notes, zcProjectName, zgHiliteGraphic, zgCurrentRecordID, zcCurrentRecordIndicator, zgDeletionGraphic, DateEntered, zcRecordsFound, zcConstantKey, Type, Amount, CheckNo, zgTempHolder, ExpendRecID, zcProjectStartDate, DatePaid, Description, Name, zcPrevious Balance, zgFileInitialized, zgFileName, zgCategory, zgLastLayout, Category

### 12. prj_PTC__Participants (68,497 rows)
Event participants/registrations.

Key columns: `ParticipantID`, `EventID`, `Name`, `PersonID`, `Role`, `Status`, `Invited`, `Replied`, `Attended`, `Paid`, `NoOfPersons`, `AmountPaid`, `Comments`, `Fee`, `Balance`, `Year`, `OrgID`, `ProjectID`, `AllocRecID`

Full columns (98): ParticipantID, EventID, Name, Phone, Notes, zcLastFirstName, zcEventTitle, zcYear, zcCategory, zgHiliteGraphic, zgCurrentRecordID, zcCurrentRecordIndicator, zgDeletionGraphic, DateEntered, zcLastName, zcRecordsFound, zcConstantKey, Status, zgParticipantIDs, zcLastFirstNameID, zsEventCount, Invited, Replied, Attended, Paid, zcSetLink, zcRoloViaNameID, zgTempHolder, zcParticipantIDEventID, NoOfPersons, zcAmountPaid, zcEventDate, PRecID, ProjectID, AllocRecID, zgPRecID, zgTab1, zgTab2, zgTab3, zgTab4, zgTab5, zgTab6, zgTab7, zcFunder, zcProjectName, zcTrngAlloc, zcMark, zgFileInitialized, zcCountPayments, Comp, Role, zcMailingList, zsTotalNumber, zcRoleKey, zcCountAttended, zcCountRepliedYes, zgTempID, HostID, zcHostIDEventID, zcHostKey, zcCountHostGuests, zcHostIDGuestID, zgSelectedEventID, zcAmountPaidCopy, zcHostName, zgSetLinkBtn, zcSetLinkBtn, zcTotalHostGuestAmount, zcCountRepliedNo, zcCountHostGuestsAttending, zcCountHostGuestsNotAttending, zcCountHostGuestsPossible, zcCountNoReply, zgTempText1, zgTempText2, zgTempText3, zgTempText4, Year, zcYearParticID, zgReportTitle, zcBasis, zcDeletionGraphic, Comments, BidderNumbers, CEHours, SubmissionID, EnteredBy, ModifiedBy, DateTimeModified, zcLastStatus, zcStatus, zcIsLinkedRolodex, OrgID, Fee, AmountPaid, zcBalance, PaymentID, Organization, zcEventFeeType

### 13. prj_org_ADR__Addresses (28,398 rows)
Organization addresses.

Key columns: `AddrsID`, `AddrsLine1`, `AddrsLine2`, `AddrsCity`, `AddrsState`, `AddrsPostalCode`, `AddrsCountry`, `AddrsType`, `Primacy`, `RolodexID`, `OrgID`, `Note`

Full columns (24): AddrsID, AddrsLine1, AddrsLine2, AddrsCity, AddrsState, AddrsPostalCode, AddrsCountry, AddrsType, Primacy, RolodexID, OrgID, PostalCodeLookup, zgAddrsID, zgTempID, UnusedField, StreetNo, ModificationDateTime, AddrsFormat, zaChangeLog, zcAddrsLabel, DateEntered, Note, zcAddrsMatch, zcName

### 14. prj_prs_ADR__Addresses (28,398 rows)
Personnel addresses (identical schema to org addresses).

Full columns (24): AddrsID, AddrsLine1, AddrsLine2, AddrsCity, AddrsState, AddrsPostalCode, AddrsCountry, AddrsType, Primacy, RolodexID, OrgID, PostalCodeLookup, zgAddrsID, zgTempID, UnusedField, StreetNo, ModificationDateTime, AddrsFormat, zaChangeLog, zcAddrsLabel, DateEntered, Note, zcAddrsMatch, zcName

### 15. prj_org_PHN__Phones (33,915 rows)
Organization phone numbers.

Key columns: `PhoneID`, `RolodexID`, `PhoneNumber`, `Country`, `PhoneType`, `Primacy`, `OrgID`, `Note`

Full columns (16): PhoneID, RolodexID, PhoneNumber, Country, PhoneType, Primacy, OrgID, zgPhoneID, zgTempID, Note, ModificationDateTime, zaChangeLog, DateEntered, zcOrgPhone, zcAlsoOrgPhone, zcIsDuplicate

### 16. prj_FND__FundingviaTempID (1,391 rows)
Funding sources/grants.

Key columns: `RecordID`, `FunderID`, `Status`, `GrantType`, `Category`, `AmountGranted`, `RequestAmount`, `StartDate`, `EndDate`, `Source`, `Purpose`, `Active`, `ScopeGranted`, `GeographicScope`, `ProgramScope`, `TrainingsBudgeted`, `GeneralBudget`, `SupplyBudget`, `ExhibitBudget`

Full columns (112): RecordID, FunderID, Date Entered, Status, Notes, ModifiedBy, Submission, zcFunderName, zcFunderNameAlphaSorted, zcFunderContact, DateModified, EnteredBy, RequestAmount, FirmDeadline, TargetDeadline, NameTemp, StartDate, EndDate, Purpose, ReportDueDate, ReportDescription, ReconciliationDue, DateReq, ReportIn, Source, Month, zgInfoGraphic, AmountGranted, zcStartEnd Dates, zcAmountCalc, DateReportSent, zcReportIn, zcNextReportDate, zcReportDatesStillDue, zgFieldReps, zcReportStillDue, zcNextReportDescription, zcOverdue, zgMonth, zgYear, zcReportingDate, zcMonthNo, zcReportDue, zcNextFinlReport, zcFinlReportStillDue, zcConstant, zcRecordsFound, zcIncludeInReport, zcSubmDeadline1, zgStatusSelector, zgStartDate, zgEndDate, zcCountOrgIDs, zcPrimaryContact, zcSubmDeadlineTxt, zgActiveStatusKey, zcTotalAllocations, zcTotalAllocGenl, zcTotalAllocSupl, zcRemainingAmtTtl, GrantType, TrainingsBudgeted, CostPerTraining, zcTrainingBudget, GeneralBudget, SupplyBudget, zcRemainingAmtGenl, zcRemainingAmtSupl, zcTotalTrainings, zcTotalBudget, zcBudgetDiscrep, zcRemainingTrainings, Active, Category, NotificationDate, zcKeyDate, zcKeyYear, zgYearSelector, zcAmountLabel, zcKeyDateLabel, zgYearSelectorEnd, zsTotalAmountCalc, zsRecordCount, zcCatDateKey, zgCategorySelector, zgStatusSelector1, NonAllocated, zgFileInitialized, SubmissionDate, NotifyDateEst, zgLastLayout, zgMarkedRecords, zgTempText, zgCurrentRecordID, zgFileName, zcMark, zcCountMarkedRecords, zsMarkedRecords, zgBtn1, zgBtn2, zgBtn3, zgBtn4, zgBtn5, zgBtn6, zgBtn7, zgBtn8, zgTab1, zgTab2, zgTab3, zgTab4, zgTab5, zgTempHolder, zcTotalPayments, zcBalance, zcPaymentStatus, zgReportSelector, zsTotalPaymentsCalc, zsTotalBalanceCalc, KeyYearOverride, zgTempID, ScopeGranted, GeographicScope, ProgramScope, zgProgramID, zcTotalAmtMatched, zcMatchingGrantBalance, zcCountMatchDonations, ExhibitBudget, zcTotalAllocExhib, zcRemainingAmtExhib

### 17. prj_PSP__ProgramSponsorships (608 rows)
Program sponsorship links (funders sponsoring programs).

Key columns: `RecordID`, `FundingID`, `ProgramID`, `FunderID`, `QuotationID`, `Status`, `Notes`, `StartDate`, `EndDate`, `zcFunderName`, `zcSponsorName`

Full columns (24): RecordID, DateCreated, CreatedBy, DateTimeModified, ModifiedBy, FundingID, ProgramID, Notes, StartDate, zgDeletionGraphic, zcFunderName, FunderID, EndDate, QuotationID, Status, zgQuotationFlagsSelector, zgTempID, zcCountQuotationsByProject, zgStartDate, zgEndDate, zcSponsorName, MessageText, zgImageID, zgRecordID

### 18. prj_PZC__CityState (80,134 rows)
City/State/ZIP code lookup/reference data.

Key columns: `Preferred`, `Zipcode`, `State`, `City`, `County`, `AreaCode`, `FIPS`, `TimeZone`, `Latitude`, `Longitude`, `Type`, `Population`

Full columns (14): Preferred, Zipcode, State, City, County, AreaCode, FIPS, TimeZone, DaylightSavings, Latitude, Longitude, Type, Population, PrefSort

---

## Relationship Summary

### How tables connect (key foreign keys):

| Source | FK Column | Target Table | Target PK |
|--------|-----------|-------------|-----------|
| `prj_RDX__Rolodex` | `ID` | (self) | `ID` |
| `prj_RDX__Rolodex` | `OrgID` | `prj_ORG__Organization` | `OrgID` |
| `PRJ__Projects` | `OrgID` | `prj_ORG__Organization` | `OrgID` |
| `PRJ__Projects` | `FacilityID` | `prj_RDX__Rolodex` | `ID` |
| `prj_PRS__Personnel` | `PersonID` | `prj_RDX__Rolodex` | `ID` |
| `prj_PRS__Personnel` | `ProjectID` | `PRJ__Projects` | `ProjectID` |
| `prj_SRV__Service` | `ProjectID` | `PRJ__Projects` | `ProjectID` |
| `WORKSHOPLOG` | `ProjectID` | `PRJ__Projects` | `ProjectID` |
| `WORKSHOPLOG` | `LeaderID` | `prj_RDX__Rolodex` | `ID` |
| `WORKSHOPLOG` | `AgencyID` | `prj_RDX__Rolodex` | `ID` |
| `prj_ALC__Allocations` | `FundingRecID` | `prj_FND__FundingviaTempID` | `RecordID` |
| `prj_ALC__Allocations` | `ProjectID` | `PRJ__Projects` | `ProjectID` |
| `prj_EXP__Expenditure` | `ProjectID` | `PRJ__Projects` | `ProjectID` |
| `prj_EVT__Events` | `EventID` | (self) | `EventID` |
| `prj_PTC__Participants` | `EventID` | `prj_EVT__Events` | `EventID` |
| `prj_PTC__Participants` | `ProjectID` | `PRJ__Projects` | `ProjectID` |
| `prj_PTC__Participants` | `ParticipantID` | `prj_RDX__Rolodex` | `ID` |
| `prj_PTC__Participants` | `AllocRecID` | `prj_ALC__Allocations` | `AllocRecID` |
| `prj_PTC__Participants` | `OrgID` | `prj_ORG__Organization` | `OrgID` |
| `prj_PTC__Participants` | `PaymentID` | `prj_PMT__Payment` | `RecordID` |
| `prj_PMT__Payment` | `RolodexID` | `prj_RDX__Rolodex` | `ID` |
| `prj_PMT__Payment` | `OrgID` | `prj_ORG__Organization` | `OrgID` |
| `prj_PMT__Payment` | `ProjectID` | `PRJ__Projects` | `ProjectID` |
| `prj_PMT__Payment` | `ParticRecID` | `prj_PTC__Participants` | `PRecID` |
| `prj_NTS__Notes` | `RolodexID` | `prj_RDX__Rolodex` | `ID` |
| `prj_NTS__Notes` | `OrgID` | `prj_ORG__Organization` | `OrgID` |
| `prj_NTS__Notes` | `ProjectID` | `PRJ__Projects` | `ProjectID` |
| `prj_NTS__Notes` | `EventID` | `prj_EVT__Events` | `EventID` |
| `prj_org_ADR__Addresses` | `RolodexID` | `prj_RDX__Rolodex` | `ID` |
| `prj_org_ADR__Addresses` | `OrgID` | `prj_ORG__Organization` | `OrgID` |
| `prj_prs_ADR__Addresses` | `RolodexID` | `prj_RDX__Rolodex` | `ID` |
| `prj_org_PHN__Phones` | `RolodexID` | `prj_RDX__Rolodex` | `ID` |
| `prj_org_PHN__Phones` | `OrgID` | `prj_ORG__Organization` | `OrgID` |
| `prj_FND__FundingviaTempID` | `RecordID` | (self) | `RecordID` |
| `prj_PSP__ProgramSponsorships` | `FundingID` | `prj_FND__FundingviaTempID` | `RecordID` |
| `prj_PSP__ProgramSponsorships` | `FunderID` | `prj_RDX__Rolodex` | `ID` |

### Allocation Data Flow

The allocation/funding chain in FileMaker flows as:

```
prj_FND__FundingviaTempID (grants/funding sources, 1,391 rows)
  └─ FundingRecID → prj_ALC__Allocations (funding → project allocations, 3,099 rows)
       └─ ProjectID → PRJ__Projects (project receiving the allocation)
       └─ AllocRecID → prj_PTC__Participants (participants drawing from this allocation)

prj_PTC__Participants (event participants/registrations, 68,497 rows)
  └─ EventID → prj_EVT__Events (event they registered for)
  └─ PersonID → prj_RDX__Rolodex (individual person)
  └─ PaymentID → prj_PMT__Payment (payment/link to payment record)
  └─ AllocRecID → prj_ALC__Allocations (funding allocation covering their participation)

prj_PMT__Payment (donations and payments, 27,146 rows)
  └─ RolodexID → prj_RDX__Rolodex (payer/donor)
  └─ ParticRecID → prj_PTC__Participants (participant this payment is for)
  └─ OrgID → prj_ORG__Organization (org linked to payment)
  └─ ProjectID → PRJ__Projects (project linked to payment)
```

### Notes
- The `prj_psp_FND__Funding` table is an alias for `prj_FND__FundingviaTempID` (same data, same count 1,391).
- All `exp_*`, `prs_*`, `srv_*`, `wsl_*` prefixed tables are FileMaker contextual references to the same underlying data (same counts verified).
- The `_kf_sqlUser_ID` column on `prj_RDX__Rolodex` suggests a sync mechanism from FileMaker to SQL.
- `zcConstantKey` = 1.0 appears on many tables as a FileMaker constant relationship key.
- `zcRecordsFound` contains display strings like "Record 1 of 2 Found\r39608 Total" from FileMaker layout context.
