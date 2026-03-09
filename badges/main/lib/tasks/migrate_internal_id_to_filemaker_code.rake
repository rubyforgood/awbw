namespace :organizations do
  desc "Migrate internal_id to filemaker_code for organizations"
  task migrate_internal_id_to_filemaker_code: :environment do
    puts "Starting migration of internal_id to filemaker_code..."
    puts "Environment: #{Rails.env}"
    puts "==============================================="

    migrated_count = 0
    commented_count = 0
    skipped_count = 0

    Organization.where.not(internal_id: [ nil, "" ]).find_each do |org|
      internal_stripped = org.internal_id.strip
      filemaker_stripped = org.filemaker_code&.strip

      if !filemaker_stripped.present? && internal_stripped.present?
        org.update!(filemaker_code: internal_stripped)
        migrated_count += 1
        puts "Migrated org #{org.id} (#{org.name}): filemaker_code set to '#{internal_stripped}'"
      elsif internal_stripped != filemaker_stripped
        org.comments.create!(
          body: "Data migration note: internal_id '#{org.internal_id}' did not match filemaker_code '#{org.filemaker_code}'"
        )
        commented_count += 1
        puts "Mismatch org #{org.id} (#{org.name}): internal_id='#{org.internal_id}' vs filemaker_code='#{org.filemaker_code}' — comment added"
      else
        skipped_count += 1
        puts "Skipped org #{org.id} (#{org.name}): values already match"
      end
    end

    puts "==============================================="
    puts "Migration complete!"
    puts "Migrated: #{migrated_count}"
    puts "Mismatches commented: #{commented_count}"
    puts "Skipped (already matching): #{skipped_count}"
  end
end
