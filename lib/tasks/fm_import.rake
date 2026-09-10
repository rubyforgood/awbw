# frozen_string_literal: true

namespace :fm do
  desc "Import FileMaker CSVs from FM Archive Resources into archive tables"
  task import: :environment do
    require "csv"

    BATCH_SIZE = 1000

    IMPORTS = [
      { model: FmRolodex, csv: "Rolodex.csv", key: "ID" },
      { model: FmOrganization, csv: "Organizations.csv", key: "OrgID" },
      { model: FmProject, csv: "Projects.csv", key: "ProjectID" },
      { model: FmEvent, csv: "Events.csv", key: "EventID" },
      { model: FmService, csv: "Service.csv", key: "RecordID" },
      { model: FmPersonnel, csv: "Personnel.csv", key: "PrsnlRecID" },
      { model: FmPayment, csv: "Payments.csv", key: "RecordID" },
      { model: FmParticipant, csv: "Participants.csv", key: "PRecID" },
      { model: FmActivity, csv: "Activity.csv", key: "ActivityLogID" },
      { model: FmNote, csv: "Notes.csv", key: "NoteID" },
      { model: FmAddress, csv: "Addresses.csv", key: "AddrsID" },
      { model: FmPhoneNumber, csv: "PhoneNumbers.csv", key: "PhoneID" },
      { model: FmWorkshopLog, csv: "WorkshopLogs.csv", key: "RecordID" },
      { model: FmExpenditure, csv: "Expenditure.csv", key: "ExpendRecID" },
      { model: FmFunding, csv: "Funding.csv", key: "RecordID" },
      { model: FmAllocation, csv: "Allocations.csv", key: "AllocRecID" },
      { model: FmProgramSponsorship, csv: "ProgramSponsorships.csv", key: "RecordID" },
      { model: FmPostalCode, csv: "PostalCodes.csv", key: "Zipcode" },
      { model: FmAncillaryData, csv: "AncillaryData.csv", key: "RecordID" },
      { model: FmArtPurchase, csv: "ArtPurchases.csv", key: "PurchaseID" },
      { model: FmArtRegistry, csv: "ArtRegistry.csv", key: "ItemID" },
      { model: FmCampaign, csv: "Campaigns.csv", key: "CampaignID" },
      { model: FmCommitteeMeeting, csv: "CommitteeMeetings.csv", key: "CtMtgID" },
      { model: FmCommitteeMember, csv: "CommitteeMembers.csv", key: "CMRecID" },
      { model: FmCommittee, csv: "Committees.csv", key: "CommitteeID" },
      { model: FmContact, csv: "Contacts.csv", key: "ContactID" },
      { model: FmDonorDeveloper, csv: "DonorDevelopers.csv", key: "DonorDevRecID" },
      { model: FmEmailAddress, csv: "EmailAddresses.csv", key: "EmailAddrsID" },
      { model: FmExhibitedItem, csv: "ExhibitedItems.csv", key: "RecordID" },
      { model: FmFormField, csv: "FormFields.csv", key: "FieldNo" },
      { model: FmFormLetter, csv: "FormLetters.csv", key: "DocID" },
      { model: FmFormsList, csv: "FormsList.csv", key: "FormID" },
      { model: FmFormSubmission, csv: "FormSubmissions.csv", key: "RecordID" },
      { model: FmGroupMember, csv: "GroupMembers.csv", key: "RecordID" },
      { model: FmGroup, csv: "Groups.csv", key: "GroupID" },
      { model: FmInvoice, csv: "Invoice.csv", key: "RecordID" },
      { model: FmLineItem, csv: "LineItem.csv", key: "ItemID" },
      { model: FmMatchDonation, csv: "MatchDonations.csv", key: "RecordID" },
      { model: FmPeopleToOrganization, csv: "PeopleToOrganizations.csv", key: "RecordID" },
      { model: FmQuotation, csv: "Quotations.csv", key: "RecordID" },
      { model: FmReporting, csv: "Reporting.csv", key: "ReportID" },
      { model: FmSolicitation, csv: "Solicitations.csv", key: "SolicitationID" },
      { model: FmVolunteer, csv: "Volunteer.csv", key: "VolID" },
      { model: FmWorkshop, csv: "Workshops.csv", key: "WorkshopID" }
    ]

    # Find all FM Archive resources
    resources = Resource.where(kind: "FM Archive")
    if resources.empty?
      puts "No FM Archive resources found."
      puts "Upload your CSVs as Resources with kind='FM Archive' first."
      exit 1
    end

    puts "Found #{resources.size} FM Archive resources:"
    resources.each { |r| puts "  #{r.title} (#{r.downloadable_asset&.file&.filename})" }
    puts ""

    total = 0

    IMPORTS.each do |config|
      csv_filename = config[:csv]

      # Find resource by matching CSV filename
      resource = resources.find do |r|
        r.downloadable_asset&.file&.filename.to_s.downcase == csv_filename.downcase
      end

      unless resource
        puts "SKIP: No resource found for #{csv_filename}"
        next
      end

      model = config[:model]
      key_col = config[:key]
      table_name = model.table_name
      puts "Importing #{csv_filename} → #{table_name}..."

      existing_ids = model.pluck(:fm_id).to_set
      puts "  #{existing_ids.size} existing rows, skipping duplicates"

      csv_data = resource.downloadable_asset.file.download.force_encoding("UTF-8")
      batch = []
      count = 0
      skipped = 0

      CSV.parse(csv_data, headers: true) do |row|
        fm_id = row[key_col]
        next if fm_id.nil? || fm_id.to_s.strip.empty?

        fm_id = fm_id.to_s.strip
        if existing_ids.include?(fm_id)
          skipped += 1
          next
        end

        data = row.to_h.except(key_col).compact
        data = {} if data.nil?
        next if data.empty?

        batch << { fm_id: fm_id, fm_key_name: key_col, data: data }

        if batch.size >= BATCH_SIZE
          model.insert_all(batch)
          count += batch.size
          batch.clear
        end
      end

      if batch.any?
        model.insert_all(batch)
        count += batch.size
      end

      puts "  #{count} rows imported, #{skipped} skipped (already exist)"
      total += count
    end

    puts "\nDone: #{total} total rows imported."
  end
end
