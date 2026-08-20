class CreateFmArchiveTables < ActiveRecord::Migration[8.1]
  def up
    tables = {
      fm_rolodexes: "ID",
      fm_organizations: "OrgID",
      fm_projects: "ProjectID",
      fm_events: "EventID",
      fm_services: "RecordID",
      fm_personnels: "PrsnlRecID",
      fm_payments: "RecordID",
      fm_participants: "ParticipantID",
      fm_activities: "ActivityLogID",
      fm_notes: "NoteID",
      fm_addresses: "AddrsID",
      fm_phone_numbers: "PhoneID",
      fm_workshop_logs: "RecordID",
      fm_expenditures: "ExpendRecID",
      fm_funding: "RecordID",
      fm_allocations: "AllocRecID",
      fm_program_sponsorships: "RecordID",
      fm_postal_codes: "Zipcode",
    }

    tables.each do |table_name, key_col|
      create_table table_name do |t|
        t.string :fm_id, null: false
        t.string :fm_key_name, null: false, default: key_col
        t.json :data, null: false
        t.timestamps
      end
      add_index table_name, :fm_id, unique: true
    end
  end

  def down
    %i[
      fm_rolodexes fm_organizations fm_projects fm_events fm_services
      fm_personnels fm_payments fm_participants fm_activities fm_notes
      fm_addresses fm_phone_numbers fm_workshop_logs fm_expenditures
      fm_funding fm_allocations fm_program_sponsorships fm_postal_codes
    ].each do |table_name|
      drop_table table_name if table_exists?(table_name)
    end
  end
end
