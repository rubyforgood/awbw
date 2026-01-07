namespace :rhino_migrator do
  desc "Migrate Resource.text into ActionText using RichTextMigrator"
  task resource: :environment do
    old_column = :text

    puts "Starting RichText migration for Resource##{old_column}"

    Resource.find_each(batch_size: 100) do |resource|
      begin
        RichTextMigrator.new(resource, old_column).migrate!
      rescue => e
        puts "\nFailed to migrate Resource ID=#{resource.id}: #{e.class} - #{e.message}"
      end
    end

    puts "\nMigration complete."
  end
end
