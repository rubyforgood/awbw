namespace :affiliations do
  desc "Populate person_id from user_id in affiliations table"
  task migrate_user_to_person: :environment do
    puts "🚀 Starting migration of user_id to person_id in affiliations..."
    puts "Environment: #{Rails.env}"
    puts "==============================================="

    # Find all affiliation records that have user_id but no person_id
    records_to_update = Affiliation.where.not(user_id: nil).where(person_id: nil)

    puts "Found #{records_to_update.count} records to update"

    if records_to_update.count == 0
      puts "✅ No records need updating. All affiliations already have person_id populated."
      return
    end

    updated_count = 0
    skipped_count = 0

    records_to_update.find_each do |affiliation|
      user = User.find_by(id: affiliation.user_id)

      if user&.person
        begin
          affiliation.update!(person_id: user.person.id)
          updated_count += 1
          puts "✓ Updated affiliation #{affiliation.id}: user_id #{affiliation.user_id} -> person_id #{user.person.id}"
        rescue => e
          puts "✗ Failed to update affiliation #{affiliation.id}: #{e.message}"
          skipped_count += 1
        end
      else
        puts "⚠ Skipping affiliation #{affiliation.id}: user_id #{affiliation.user_id} has no associated person"
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
