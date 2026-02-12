namespace :organization_people do
  desc "Populate person_id from user_id in organization_people table"
  task migrate_user_to_person: :environment do
    puts "🚀 Starting migration of user_id to person_id in organization_people..."
    puts "Environment: #{Rails.env}"
    puts "==============================================="

    # Find all organization_people records that have user_id but no person_id
    records_to_update = OrganizationPerson.where.not(user_id: nil).where(person_id: nil)

    puts "Found #{records_to_update.count} records to update"

    if records_to_update.count == 0
      puts "✅ No records need updating. All organization_people already have person_id populated."
      return
    end

    updated_count = 0
    skipped_count = 0

    records_to_update.find_each do |org_person|
      user = User.find_by(id: org_person.user_id)

      if user&.person
        begin
          org_person.update!(person_id: user.person.id)
          updated_count += 1
          puts "✓ Updated organization_person #{org_person.id}: user_id #{org_person.user_id} -> person_id #{user.person.id}"
        rescue => e
          puts "✗ Failed to update organization_person #{org_person.id}: #{e.message}"
          skipped_count += 1
        end
      else
        puts "⚠ Skipping organization_person #{org_person.id}: user_id #{org_person.user_id} has no associated person"
        skipped_count += 1
      end
    end

    puts "==============================================="
    puts "Migration complete!"
    puts "✅ Successfully updated: #{updated_count} records"
    puts "⚠ Skipped: #{skipped_count} records"
    puts "Total records processed: #{records_to_update.count}"
  end
end
