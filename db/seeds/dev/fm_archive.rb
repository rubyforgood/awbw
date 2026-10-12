# FileMaker archive seeds (dev-only) - run on their own via `rake db:seed:fm_archive`,
# or as part of `rake db:seed:dev`. Three fake rows per archive table: rows 1-2 point
# at each other, row 3 carries IDs the archive has no row for, as the real export does.
# Then the alphabetically-first people, organizations, their affiliations, payments and
# workshops (when seeded) get FileMaker codes — some resolve, some don't (see ADR-0005).

puts "Creating FileMaker archive records…"

fm_ids = {
  rolodex: %w[00901 00902 00903],
  organization: %w[ORG90001 ORG90002 ORG90003],
  project: %w[P9001 P9002 P9003],
  event: %w[E9001 E9002 E9003],
  service: %w[71001 71002 71003],
  personnel: %w[PS9001 PS9002 PS9003],
  payment: %w[D90001 D90002 D90003],
  participant: %w[72001 72002 72003],
  activity: %w[73001 73002 73003],
  note: %w[N90001 N90002 N90003],
  address: %w[74001 74002 74003],
  phone_number: %w[75001 75002 75003],
  workshop_log: %w[76001 76002 76003],
  expenditure: %w[X9001 X9002 X9003],
  funding: %w[F9001 F9002 F9003],
  allocation: %w[77001 77002 77003],
  program_sponsorship: %w[PSP9001 PSP9002 PSP9003],
  postal_code: %w[90013 90291 91101],
  ancillary_data: %w[78001 78002 78003],
  art_purchase: %w[79001 79002 79003],
  art_registry: %w[81001 81002 81003],
  campaign: %w[C901 C902 C903],
  committee_meeting: %w[82001 82002 82003],
  committee_member: %w[83001 83002 83003],
  committee: %w[84001 84002 84003],
  contact: %w[85001 85002 85003],
  donor_developer: %w[86001 86002 86003],
  email_address: %w[87001 87002 87003],
  exhibited_item: %w[88001 88002 88003],
  form_field: %w[901 902 903],
  form_letter: %w[61001 61002 61003],
  forms_list: %w[62001 62002 62003],
  form_submission: %w[FSB90001 FSB90002 FSB90003],
  group_member: %w[63001 63002 63003],
  group: %w[G90001 G90002 G90003],
  invoice: %w[64001 64002 64003],
  line_item: %w[65001 65002 65003],
  match_donation: %w[66001 66002 66003],
  people_to_organization: %w[67001 67002 67003],
  quotation: %w[Q90001 Q90002 Q90003],
  reporting: %w[68001 68002 68003],
  solicitation: %w[69001 69002 69003],
  volunteer: %w[70001 70002 70003],
  workshop: %w[W9001 W9002 W9003]
}

fm_ref = ->(table, i) { i < 2 ? fm_ids[table][i] : fm_ids[table].first.sub(/\d{3}\z/, "999") }

def seed_fm(model, fm_ids)
  fm_ids.each_with_index do |fm_id, i|
    model.find_or_initialize_by(fm_id: fm_id).update!(fm_key_name: model::FM_KEY_COLUMN, data: yield(i).compact)
  end
end

people = Person.order(:first_name, :last_name).first(3)
organizations = Organization.order(:name).first(3)
affiliations = Affiliation.joins(:person).where(person: people).or(Affiliation.joins(:person).where(organization: organizations))
                          .order("people.first_name, people.last_name, affiliations.id").first(3)
payments = (Payment.where(person: people).or(Payment.where(organization: organizations)).order(:id).first(3) +
            Payment.order(:id).limit(3)).uniq.first(3)
workshops = Workshop.order(:title).first(3)

workshop_titles = [ workshops[0]&.title || "Comfort Journals", workshops[1]&.title || "Watercolor Windows", "Story Dolls" ]
payment_amounts = [ payments[0], payments[1] ].map { |payment| payment && format("%.2f", payment.amount_cents / 100.0) }
payment_amounts = [ payment_amounts[0] || "150.00", payment_amounts[1] || "500.00", "75.00" ]

first_names = [ people[0]&.first_name || "Delia", people[1]&.first_name || "Theo", "Janelle" ]
last_names = [ people[0]&.last_name || "Marquez", people[1]&.last_name || "Brandt", "Okafor" ]
org_names = [ organizations[0]&.name || "Harbor Light Family Shelter", organizations[1]&.name || "Sunrise House", "Casa Esperanza Women's Center" ]
full_names = first_names.zip(last_names).map { |name| name.join(" ") }
entered_dates = %w[03/14/2011 09/02/2014 06/21/2018]
entered_by = %w[mbrown jlee admin]

seed_fm FmRolodex, fm_ids[:rolodex] do |i|
  {
    "OrgID" => fm_ref[:organization, i],
    "PrimaryContactID" => i == 1 ? fm_ids[:rolodex][0] : nil,
    "PrimaryAddrsID" => fm_ref[:address, i],
    "PrimaryPhoneID" => fm_ref[:phone_number, i],
    "NamePrefix" => %w[Ms. Mr. Dr.][i],
    "FirstName" => first_names[i],
    "LastName" => last_names[i],
    "Pronouns" => %w[she/her he/him they/them][i],
    "Title" => [ "Program Director", "Case Manager", "Clinical Supervisor" ][i],
    "Organization" => org_names[i],
    "Classification" => %w[Facilitator Donor Facilitator][i],
    "Status" => %w[Active Active Inactive][i],
    "EMail" => "#{first_names[i]}.#{last_names[i]}@example.com".downcase.delete(" "),
    "FacilitatorSinceYear" => %w[2011 2014 2018][i],
    "HowTrained" => [ "In-person training", "Online training", "In-person training" ][i],
    "PrimaryAgeGroup" => %w[Adults Teens Children][i],
    "PrimaryServiceArea" => [ "Domestic Violence", "Homelessness", "Child Abuse" ][i],
    "MailingList" => %w[Yes Yes No][i],
    "EnteredBy" => entered_by[i],
    "DateEntered" => entered_dates[i]
  }
end

seed_fm FmOrganization, fm_ids[:organization] do |i|
  {
    "ParentID" => i == 1 ? fm_ids[:organization][0] : nil,
    "OrgName" => org_names[i],
    "OrgType" => [ "Domestic Violence Shelter", "Transitional Housing", "Family Services" ][i],
    "Classification" => %w[Agency Agency Funder][i],
    "Status" => %w[Active Active Closed][i],
    "Website" => "https://www.example.org/#{org_names[i].parameterize}",
    "Mission" => "Safe shelter and healing for women and children leaving violence.",
    "OutreachStatus" => %w[Contacted Partner None][i],
    "CreatedBy" => entered_by[i],
    "CreationDate" => entered_dates[i]
  }
end

seed_fm FmProject, fm_ids[:project] do |i|
  {
    "OrgID" => fm_ref[:organization, i],
    "MergerWithID" => i == 2 ? fm_ids[:project][0] : nil,
    "ProjectName" => "#{org_names[i]} Art Program",
    "ProjectType" => %w[Windows Windows Community][i],
    "AgencyType" => [ "Domestic Violence", "Homeless Services", "Youth Services" ][i],
    "Status" => %w[Active Active Merged][i],
    "PrimarySetting" => [ "Shelter", "Transitional Housing", "Outpatient" ][i],
    "PrimaryServiceArea" => [ "Domestic Violence", "Homelessness", "Child Abuse" ][i],
    "City" => [ "Los Angeles", "Venice", "Pasadena" ][i],
    "County" => "Los Angeles",
    "State" => "CA",
    "SPA" => %w[4 5 3][i],
    "StartDate" => entered_dates[i],
    "EnteredBy" => entered_by[i]
  }
end

seed_fm FmEvent, fm_ids[:event] do |i|
  {
    "Title" => [ "Facilitator Training — Los Angeles", "Spring Art Auction", "Online Facilitator Training" ][i],
    "Category" => %w[Training Fundraiser Training][i],
    "Type" => %w[In-person Gala Online][i],
    "Available" => %w[Yes No Yes][i],
    "EventDate" => %w[04/12/2019 05/18/2019 10/03/2020][i],
    "EndDate" => %w[04/13/2019 05/18/2019 10/04/2020][i],
    "StartTime" => [ "9:00 AM", "6:00 PM", "10:00 AM" ][i],
    "Year" => %w[2019 2019 2020][i],
    "Location" => [ "AWBW Studio, Marina del Rey", "Santa Monica Art Studios", "Zoom" ][i],
    "Fee" => %w[150 125 150][i],
    "MaxParticipants" => %w[30 200 40][i],
    "EnteredBy" => entered_by[i],
    "DateEntered" => entered_dates[i]
  }
end

seed_fm FmService, fm_ids[:service] do |i|
  {
    "ProjectID" => fm_ref[:project, i],
    "Year" => "2019",
    "Month" => %w[January February March][i],
    "NewAdult" => %w[12 8 5][i],
    "NewTeen" => %w[3 0 2][i],
    "NewChild" => %w[6 4 9][i],
    "OngoingAdult" => %w[20 15 11][i],
    "OngoingTeen" => %w[4 2 1][i],
    "OngoingChild" => %w[10 7 12][i],
    "LateCard" => %w[No No Yes][i],
    "CreatedBy" => entered_by[i]
  }
end

seed_fm FmPersonnel, fm_ids[:personnel] do |i|
  {
    "PersonID" => fm_ref[:rolodex, i],
    "ProjectID" => fm_ref[:project, i],
    "AgmtID" => "FSB0256#{i + 1}",
    "Name" => full_names[i],
    "Role" => %w[Facilitator Supervisor Facilitator][i],
    "ProjectType" => "Windows",
    "Status" => %w[Active Active Dropped][i],
    "AgreementStatus" => %w[Signed Signed Pending][i],
    "Update" => %w[Current Current Overdue][i],
    "EnteredBy" => entered_by[i],
    "DateEntered" => entered_dates[i]
  }
end

seed_fm FmPayment, fm_ids[:payment] do |i|
  {
    "RolodexID" => fm_ref[:rolodex, i],
    "OrgID" => fm_ref[:organization, i],
    "ProjectID" => fm_ref[:project, i],
    "ParticRecID" => fm_ref[:participant, i],
    "PledgeID" => i == 1 ? fm_ids[:payment][0] : nil,
    "FormSubmissionID" => fm_ids[:form_submission][i],
    "RefID" => [ fm_ids[:event][0], fm_ids[:funding][0], "E9999" ][i],
    "Name" => full_names[i],
    "Description" => [ "Training registration", "Spring auction donation", "Training registration" ][i],
    "Type" => %w[Payment Donation Payment][i],
    "Category" => %w[Training Individual Training][i],
    "Year" => %w[2019 2019 2020][i],
    "Amount" => payment_amounts[i],
    "PaymentMethod" => %w[Visa Check Mastercard][i],
    "PaymentDetails" => [ "x4242 txn_9F2A11", nil, "x5100 txn_7B3C42" ][i],
    "DateReceived" => %w[03/30/2019 05/18/2019 09/15/2020][i],
    "EnteredBy" => entered_by[i]
  }
end

seed_fm FmParticipant, fm_ids[:participant] do |i|
  {
    "ParticipantID" => fm_ref[:rolodex, i],
    "EventID" => fm_ref[:event, i],
    "ProjectID" => fm_ref[:project, i],
    "OrgID" => fm_ref[:organization, i],
    "AllocRecID" => i == 0 ? fm_ids[:allocation][0] : nil,
    "PaymentID" => fm_ref[:payment, i],
    "HostID" => i == 1 ? fm_ids[:rolodex][0] : nil,
    "Name" => full_names[i],
    "Organization" => org_names[i],
    "Role" => %w[Trainee Guest Trainee][i],
    "Status" => %w[Registered Attended Cancelled][i],
    "Year" => %w[2019 2019 2020][i],
    "Attended" => %w[Yes Yes No][i],
    "Paid" => %w[Yes Yes No][i],
    "Fee" => %w[150 125 150][i],
    "CEHours" => [ "12", nil, "12" ][i],
    "EnteredBy" => entered_by[i]
  }
end

seed_fm FmActivity, fm_ids[:activity] do |i|
  {
    "ID" => fm_ref[:rolodex, i],
    "LinkID" => fm_ref[:payment, i],
    "Date" => %w[04/01/2019 05/20/2019 09/16/2020][i],
    "Type" => %w[Letter Call Email][i],
    "Category" => [ "Acknowledgment", "Follow-up", "Registration" ][i],
    "Subject" => [ "Thank you for registering", "Auction follow-up", "Training confirmation" ][i],
    "FirstName" => first_names[i],
    "LastName" => last_names[i],
    "Organization" => org_names[i],
    "TakenEntered By" => entered_by[i]
  }
end

seed_fm FmNote, fm_ids[:note] do |i|
  context = %w[Project Organizations Rolodex][i]
  link_table = { "Project" => :project, "Organizations" => :organization, "Rolodex" => :rolodex }[context]
  {
    "Context" => context,
    "LinkID" => fm_ref[link_table, i],
    "ProjectID" => context == "Project" ? fm_ref[:project, i] : nil,
    "OrgID" => context == "Organizations" ? fm_ref[:organization, i] : nil,
    "RolodexID" => context == "Rolodex" ? fm_ref[:rolodex, i] : nil,
    "Date" => entered_dates[i],
    "Subject" => [ "Site visit", "New director", "Moved out of state" ][i],
    "Note" => [ "Visited the art room; supplies running low.", "Leadership change — reconfirm contact.", "Asked to be removed from mailings." ][i],
    "Category" => %w[Program Outreach Contact][i],
    "EnteredBy" => entered_by[i]
  }
end

seed_fm FmAddress, fm_ids[:address] do |i|
  {
    "RolodexID" => fm_ref[:rolodex, i],
    "OrgID" => fm_ref[:organization, i],
    "PostalCodeLookup" => fm_ids[:postal_code][i],
    "AddrsType" => %w[Work Home Mailing][i],
    "Primacy" => %w[Primary Primary Secondary][i],
    "AddrsLine1" => [ "1234 S Spring St", "88 Rose Ave", "500 E Colorado Blvd" ][i],
    "AddrsCity" => [ "Los Angeles", "Venice", "Pasadena" ][i],
    "AddrsState" => "CA",
    "AddrsPostalCode" => fm_ids[:postal_code][i],
    "AddrsCountry" => "USA",
    "DateEntered" => entered_dates[i]
  }
end

seed_fm FmPhoneNumber, fm_ids[:phone_number] do |i|
  {
    "RolodexID" => fm_ref[:rolodex, i],
    "OrgID" => fm_ref[:organization, i],
    "PhoneType" => %w[Work Mobile Fax][i],
    "PhoneNumber" => [ "(213) 555-0101", "(310) 555-0102", "(626) 555-0103" ][i],
    "Country" => "USA",
    "Primacy" => %w[Primary Primary Secondary][i],
    "DateEntered" => entered_dates[i]
  }
end

seed_fm FmWorkshopLog, fm_ids[:workshop_log] do |i|
  {
    "ProjectID" => fm_ref[:project, i],
    "LeaderID" => fm_ref[:rolodex, i],
    "AgencyID" => fm_ref[:rolodex, i],
    "LeaderName" => full_names[i],
    "WorkshopID" => fm_ids[:workshop][i],
    "WorkshopTitle" => workshop_titles[i],
    "WorkshopDate" => %w[02/06/2019 02/13/2019 03/02/2020][i],
    "Year__c" => %w[2019 2019 2020][i],
    "MonthNumber__c" => %w[2 2 3][i],
    "TotalNew" => %w[6 4 3][i],
    "TotalOngoing" => %w[9 7 5][i],
    "Materials" => [ "Journals, markers", "Watercolors, paper", "Fabric, yarn" ][i],
    "EnteredBy" => entered_by[i]
  }
end

seed_fm FmExpenditure, fm_ids[:expenditure] do |i|
  {
    "ProjectID" => fm_ref[:project, i],
    "Type" => %w[Supplies Supplies Exhibit][i],
    "Category" => [ "Art supplies", "Art supplies", "Framing" ][i],
    "Name" => [ "Blick Art Materials", "Michaels", "Frame Shop LA" ][i],
    "Amount" => %w[245.80 112.35 680.00][i],
    "CheckNo" => %w[10421 10433 10502][i],
    "DatePaid" => %w[02/01/2019 03/04/2019 04/20/2020][i]
  }
end

seed_fm FmFunding, fm_ids[:funding] do |i|
  {
    "FunderID" => fm_ref[:rolodex, i],
    "ProgramScope" => %w[Windows Windows Trainings][i],
    "GeographicScope" => [ "Los Angeles County", "Westside", "California" ][i],
    "Status" => %w[Granted Granted Declined][i],
    "Category" => %w[Foundation Corporate Government][i],
    "GrantType" => %w[Program General Program][i],
    "Active" => %w[Yes Yes No][i],
    "Purpose" => [ "Art supplies for partner shelters", "General operating", "Facilitator trainings" ][i],
    "RequestAmount" => %w[25000 10000 50000][i],
    "AmountGranted" => [ "20000", "10000", nil ][i],
    "StartDate" => %w[01/01/2019 07/01/2019 01/01/2020][i],
    "EndDate" => %w[12/31/2019 06/30/2020 12/31/2020][i],
    "ReportDueDate" => %w[01/31/2020 07/31/2020 01/31/2021][i],
    "EnteredBy" => entered_by[i],
    "Date Entered" => entered_dates[i]
  }
end

seed_fm FmAllocation, fm_ids[:allocation] do |i|
  {
    "FundingRecID" => fm_ref[:funding, i],
    "ProjectID" => fm_ref[:project, i],
    "Year" => %w[2019 2019 2020][i],
    "Status" => %w[Active Active Closed][i],
    "Active" => %w[Yes Yes No][i],
    "AmountGeneral" => %w[5000 2500 0][i],
    "AmountSupplies" => %w[1500 1000 500][i],
    "Trainings" => %w[4 2 1][i],
    "Attended" => %w[3 2 0][i],
    "DateEntered" => entered_dates[i]
  }
end

seed_fm FmProgramSponsorship, fm_ids[:program_sponsorship] do |i|
  {
    "FunderID" => fm_ref[:rolodex, i],
    "FundingID" => fm_ref[:funding, i],
    "ProgramID" => fm_ref[:project, i],
    "Status" => %w[Active Active Ended][i],
    "StartDate" => %w[01/01/2019 07/01/2019 01/01/2020][i],
    "EndDate" => %w[12/31/2019 06/30/2020 12/31/2020][i],
    "MessageText" => "This program is made possible by a generous sponsor.",
    "CreatedBy" => entered_by[i]
  }
end

seed_fm FmPostalCode, fm_ids[:postal_code] do |i|
  {
    "City" => [ "Los Angeles", "Venice", "Pasadena" ][i],
    "State" => "CA",
    "County" => "Los Angeles",
    "FIPS" => "06037",
    "Type" => "Standard",
    "Preferred" => "P",
    "AreaCode" => %w[213 310 626][i],
    "TimeZone" => "8",
    "DaylightSavings" => "Y",
    "Latitude" => %w[34.0402 33.9925 34.1475][i],
    "Longitude" => %w[-118.2468 -118.4695 -118.1445][i],
    "Population" => %w[11772 40655 18943][i]
  }
end

seed_fm FmAncillaryData, fm_ids[:ancillary_data] do |i|
  {
    "RolodexID" => fm_ref[:rolodex, i],
    "Flag" => [ "Board alumni", "Major donor", "Do not mail" ][i],
    "FlagText" => [ "Served 2012–2016", "Lifetime giving over $5k", "Requested no mail" ][i],
    "CreatedBy" => entered_by[i],
    "CreationTimestamp" => "#{entered_dates[i]} 10:15:00"
  }
end

seed_fm FmArtRegistry, fm_ids[:art_registry] do |i|
  {
    "ArtistID" => fm_ref[:rolodex, i],
    "BuyerID" => i == 0 ? fm_ids[:rolodex][1] : nil,
    "ProjectID" => fm_ref[:project, i],
    "ArtRegistryNo" => "AR-#{fm_ids[:art_registry][i]}",
    "ArtTitle" => [ "After the Rain", "My Safe Place", "Growing Brighter" ][i],
    "ArtistAge" => %w[34 16 9][i],
    "AnonymityStatus" => [ "Anonymous", "First name only", "Anonymous" ][i],
    "Medium" => [ "Watercolor", "Collage", "Mixed media" ][i],
    "YearCreated" => %w[2018 2019 2020][i],
    "SalePrice" => [ "250", nil, nil ][i],
    "LoanStatus" => [ "Sold", "Available", "On loan" ][i],
    "ProgramName" => "#{org_names[i]} Art Program",
    "EnteredBy" => entered_by[i]
  }
end

seed_fm FmArtPurchase, fm_ids[:art_purchase] do |i|
  {
    "ArtRegistryID" => fm_ref[:art_registry, i],
    "ArtRegistryNo" => "AR-#{fm_ref[:art_registry, i]}",
    "ArtTitle" => [ "After the Rain", "My Safe Place", "Untitled" ][i],
    "BuyerID" => fm_ref[:rolodex, i],
    "LoanStatus" => %w[Sold Sold Returned][i],
    "PurchaseDate" => %w[05/18/2019 05/18/2019 06/01/2020][i],
    "AmountPaid" => %w[250 175 90][i]
  }
end

seed_fm FmCampaign, fm_ids[:campaign] do |i|
  {
    "Campaign" => [ "Annual Fund 2019", "Spring Auction 2019", "Capital Campaign" ][i],
    "CampaignStartDate" => %w[01/01/2019 02/01/2019 01/01/2018][i],
    "CampaignEndDate" => %w[12/31/2019 05/31/2019 12/31/2020][i],
    "TargetAmount" => %w[150000 60000 500000][i],
    "Current" => %w[Yes No No][i],
    "Description" => [ "Year-end individual giving", "Gala and silent auction", "Studio expansion" ][i],
    "CreatedBy" => entered_by[i]
  }
end

seed_fm FmCommittee, fm_ids[:committee] do |i|
  {
    "CommitteeName" => [ "Board of Directors", "Gala Committee", "Advisory Council" ][i],
    "CommitteeType" => %w[Board Event Advisory][i],
    "Active" => %w[Yes Yes No][i],
    "MeetingSchedule" => [ "Quarterly", "Monthly, Jan–May", "As needed" ][i],
    "DateEntered" => entered_dates[i]
  }
end

seed_fm FmCommitteeMeeting, fm_ids[:committee_meeting] do |i|
  {
    "CommitteeID" => fm_ref[:committee, i],
    "MeetingDate" => %w[03/12/2019 04/02/2019 01/15/2020][i],
    "MeetingTime" => [ "6:30 PM", "12:00 PM", "5:00 PM" ][i],
    "DateEntered" => entered_dates[i]
  }
end

seed_fm FmCommitteeMember, fm_ids[:committee_member] do |i|
  {
    "CommitteeID" => fm_ref[:committee, i],
    "MemberID" => fm_ref[:rolodex, i],
    "Active" => %w[Yes Yes No][i],
    "Role" => %w[Chair Member Member][i],
    "TermStart" => %w[01/01/2018 01/01/2019 01/01/2016][i],
    "TermEnd" => [ "12/31/2020", "12/31/2021", "12/31/2018" ][i],
    "DateEntered" => entered_dates[i]
  }
end

seed_fm FmContact, fm_ids[:contact] do |i|
  {
    "ContacteeID" => fm_ref[:rolodex, i],
    "RecordID" => fm_ids[:rolodex][(i + 1) % 3],
    "PrimaryContact" => %w[Yes No No][i],
    "Notes" => [ "Main contact at the shelter", "Assistant to the director", "Former contact" ][i],
    "EnteredBy" => entered_by[i],
    "DateEntered" => entered_dates[i]
  }
end

seed_fm FmDonorDeveloper, fm_ids[:donor_developer] do |i|
  {
    "CampaignID" => fm_ref[:campaign, i],
    "RolodexID" => fm_ref[:rolodex, i],
    "GoalAmount" => %w[10000 5000 2500][i],
    "NameListing" => full_names[i],
    "OtherAdvocateRaised" => %w[1200 0 300][i],
    "DateEntered" => entered_dates[i]
  }
end

seed_fm FmEmailAddress, fm_ids[:email_address] do |i|
  {
    "OrgID" => fm_ref[:organization, i],
    "EmailAddress" => "info@#{org_names[i].parameterize}.example.org",
    "EmailAddrsType" => %w[General Programs Billing][i],
    "Primacy" => %w[Primary Secondary Primary][i]
  }
end

seed_fm FmExhibitedItem, fm_ids[:exhibited_item] do |i|
  {
    "ArtRegistryItemID" => fm_ref[:art_registry, i],
    "EventID" => fm_ref[:event, i],
    "ItemName" => [ "After the Rain", "My Safe Place", "Weekend in Ojai" ][i],
    "ArtistDonor" => full_names[i],
    "AuctionItem" => %w[Yes No Yes][i],
    "Value" => %w[250 0 1200][i],
    "DateEntered" => entered_dates[i]
  }
end

seed_fm FmFormField, fm_ids[:form_field] do |i|
  {
    "FieldNameFM" => %w[FirstName PrimaryAgeGroup NeedScholarship][i],
    "FieldNameWP" => %w[first_name primary_age_group need_scholarship][i],
    "FieldType" => %w[Text Dropdown Checkbox][i],
    "FMValue" => [ nil, "Adults¶Teens¶Children", "Yes" ][i],
    "WPValue" => [ nil, "Adults|Teens|Children", "yes" ][i],
    "FormIDs" => fm_ids[:forms_list].first(i + 1).join(",")
  }
end

seed_fm FmFormLetter, fm_ids[:form_letter] do |i|
  {
    "SignatureID" => fm_ref[:rolodex, i],
    "DocumentName" => [ "Donation thank you", "Training confirmation", "Lapsed donor appeal" ][i],
    "DocumentText" => [ "Thank you for your generous gift.", "We're excited to see you at training.", "We miss you!" ][i],
    "Type" => %w[Acknowledgment Confirmation Appeal][i],
    "Pages" => "1",
    "Signatory" => full_names[i],
    "Date" => entered_dates[i],
    "EnteredBy" => entered_by[i]
  }
end

seed_fm FmFormsList, fm_ids[:forms_list] do |i|
  {
    "FormTitle" => [ "Facilitator Training Registration", "Annual Update", "Scholarship Application" ][i],
    "FormType" => %w[Registration Survey Application][i],
    "Description" => [ "Sign up for an in-person training", "Yearly facilitator check-in", "Request help with training fees" ][i],
    "Active" => %w[Yes Yes No][i],
    "StatusValueList" => "New¶Reviewed¶Complete"
  }
end

seed_fm FmFormSubmission, fm_ids[:form_submission] do |i|
  {
    "EntryID" => "#{4100 + i}",
    "FormID" => fm_ref[:forms_list, i],
    "EventID" => fm_ref[:event, i],
    "OrgID" => fm_ref[:organization, i],
    "RolodexID" => fm_ref[:rolodex, i],
    "ProjectID" => fm_ref[:project, i],
    "PaymentID" => fm_ref[:payment, i],
    "ParticRecID" => fm_ref[:participant, i],
    "PersonnelID" => fm_ref[:personnel, i],
    "FormTitle" => [ "Facilitator Training Registration", "Annual Update", "Scholarship Application" ][i],
    "FirstName" => first_names[i],
    "LastName" => last_names[i],
    "EmailPrimary" => "#{first_names[i]}.#{last_names[i]}@example.com".downcase.delete(" "),
    "OrgName" => org_names[i],
    "Status" => %w[Complete Complete New][i],
    "NeedScholarship" => %w[No No Yes][i],
    "PaymentAmount" => %w[150 0 75][i],
    "PaymentStatus" => %w[Paid N/A Pending][i],
    "EntryDate" => %w[03/30/2019 01/10/2020 09/15/2020][i]
  }
end

seed_fm FmGroup, fm_ids[:group] do |i|
  {
    "GroupName" => [ "Holiday card list 2019", "Gala invitees 2019", "Facilitator newsletter" ][i],
    "Category" => %w[Mailing Event Newsletter][i],
    "Type" => %w[Static Static Dynamic][i],
    "Active" => %w[Yes No Yes][i],
    "Year" => %w[2019 2019 2020][i],
    "GroupMemberCount" => %w[2 1 0][i],
    "GroupMemberIDs" => [ fm_ids[:rolodex].first(2).join("¶"), fm_ids[:rolodex][1], nil ][i],
    "CreatedBy" => entered_by[i]
  }
end

seed_fm FmGroupMember, fm_ids[:group_member] do |i|
  {
    "GroupID" => fm_ref[:group, i],
    "ContactID" => fm_ref[:rolodex, i],
    "Number" => "#{i + 1}",
    "Status" => %w[Active Active Removed][i],
    "EnteredBy" => entered_by[i],
    "DateEntered" => entered_dates[i]
  }
end

seed_fm FmInvoice, fm_ids[:invoice] do |i|
  {
    "InvoiceNo" => fm_ids[:invoice][i],
    "OrgID" => fm_ref[:organization, i],
    "RolodexID" => fm_ref[:rolodex, i],
    "Name" => full_names[i],
    "Company" => org_names[i],
    "City" => [ "Los Angeles", "Venice", "Pasadena" ][i],
    "State" => "CA",
    "Description" => [ "Facilitator training seats", "Art supply kit", "Annual membership" ][i],
    "Price" => %w[150 85 250][i],
    "Quantity" => %w[2 3 1][i],
    "AmountPaid" => %w[300 255 0][i],
    "InvoiceDate" => %w[03/01/2019 06/01/2019 01/05/2020][i],
    "DatePaid" => [ "03/20/2019", "06/18/2019", nil ][i]
  }
end

seed_fm FmLineItem, fm_ids[:line_item] do |i|
  {
    "InvoiceNo" => fm_ref[:invoice, i],
    "Description" => [ "Training seat", "Watercolor kit", "Membership" ][i],
    "Category" => %w[Training Supplies Membership][i],
    "Price" => %w[150 85 250][i],
    "Quantity" => %w[2 3 1][i],
    "Date" => %w[03/01/2019 06/01/2019 01/05/2020][i]
  }
end

seed_fm FmMatchDonation, fm_ids[:match_donation] do |i|
  {
    "FundingID" => fm_ref[:funding, i],
    "RefDonationID" => fm_ref[:payment, i],
    "DonationID" => fm_ids[:payment][i],
    "Amount" => %w[150 500 75][i],
    "Match" => %w[1:1 2:1 1:1][i]
  }
end

seed_fm FmPeopleToOrganization, fm_ids[:people_to_organization] do |i|
  {
    "PersonID" => fm_ref[:rolodex, i],
    "OrgID" => fm_ref[:organization, i],
    "Title" => [ "Program Director", "Case Manager", "Volunteer" ][i],
    "DateEntered" => entered_dates[i]
  }
end

seed_fm FmQuotation, fm_ids[:quotation] do |i|
  {
    "RolodexID" => fm_ref[:rolodex, i],
    "EventID" => fm_ref[:event, i],
    "ProjectID" => fm_ref[:project, i],
    "SourceID" => fm_ref[:rolodex, i],
    "WorkshopID" => fm_ids[:workshop][i],
    "Quotation" => [ "The art fills the room with peace.", "I can be true to myself and still be safe.", "It was the best day of my life!" ][i],
    "QuotationDate" => %w[02/06/2019 02/13/2019 03/02/2020][i],
    "Age" => %w[34 16 9][i],
    "Category" => %w[Participant Participant Participant][i],
    "WorkshopName" => workshop_titles[i],
    "ProjectName" => "#{org_names[i]} Art Program",
    "EnteredBy" => entered_by[i]
  }
end

seed_fm FmReporting, fm_ids[:reporting] do |i|
  {
    "FundingRecordID" => fm_ref[:funding, i],
    "ReportDescription" => [ "Final narrative report", "Interim report", "Budget reconciliation" ][i],
    "ReportDueDate" => %w[01/31/2020 01/31/2020 01/31/2021][i],
    "DateReportSent" => [ "01/28/2020", nil, nil ][i]
  }
end

seed_fm FmSolicitation, fm_ids[:solicitation] do |i|
  {
    "CampaignID" => fm_ref[:campaign, i],
    "DonorDevRecID" => fm_ref[:donor_developer, i],
    "DonorID" => fm_ref[:rolodex, i],
    "Status" => %w[Pledged Asked Declined][i],
    "TargetAmount" => %w[1000 500 250][i],
    "GiftLatestAmt" => [ "1000", "250", nil ][i],
    "GiftLatestDate" => [ "12/15/2019", "05/18/2019", nil ][i],
    "DonorLevelCurrYr" => %w[Patron Friend None][i],
    "NameListing" => full_names[i],
    "DateEntered" => entered_dates[i]
  }
end

seed_fm FmVolunteer, fm_ids[:volunteer] do |i|
  {
    "VRecID" => fm_ref[:rolodex, i],
    "EventID" => fm_ref[:event, i],
    "FirstName" => first_names[i],
    "LastName" => last_names[i],
    "Role" => [ "Check-in", "Auction runner", "Setup" ][i],
    "Date" => %w[04/12/2019 05/18/2019 10/03/2020][i],
    "Hours" => %w[4 6 3][i],
    "Status" => %w[Completed Completed No-show][i],
    "DateEntered" => entered_dates[i]
  }
end

seed_fm FmWorkshop, fm_ids[:workshop] do |i|
  {
    "AuthorID" => fm_ref[:rolodex, i],
    "WorkshopTitle" => workshop_titles[i],
    "AgeRange" => %w[Adults Teens Children][i],
    "ArtType" => [ "Journaling", "Painting", "Sculpture" ][i],
    "ProgramType" => "Windows",
    "TimeFrame" => [ "60 minutes", "45 minutes", "90 minutes" ][i],
    "Objective" => [ "Create a safe place to hold feelings.", "Explore feelings through color.", "Tell a story through a handmade doll." ][i],
    "Materials" => [ "Blank journals, markers, stickers", "Watercolors, brushes, paper", "Fabric scraps, yarn, glue" ][i],
    "EmotionalTheme" => %w[Comfort Expression Identity][i],
    "AuthorFirstName" => first_names[i],
    "AuthorLastName" => last_names[i],
    "EnteredBy" => entered_by[i]
  }
end

# The second record also lists a code the archive lacks; the third has only that kind.
link_codes = lambda do |records, codes|
  records.each_with_index do |record, i|
    code = [ codes[0], "#{codes[1]}, #{codes[1].sub(/\d\z/, "8")}", codes[1].sub(/\d{3}\z/, "999") ][i]
    record.update!(filemaker_code: code)
  end
end

link_codes.call(people, fm_ids[:rolodex])
link_codes.call(organizations, fm_ids[:project])
link_codes.call(affiliations, fm_ids[:personnel])
link_codes.call(payments, fm_ids[:payment])
link_codes.call(workshops, fm_ids[:workshop])
