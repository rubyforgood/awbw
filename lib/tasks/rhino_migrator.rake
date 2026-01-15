namespace :rhino_migrator do
  # ---------------------------------------------
  # INTERNAL HELPER
  # ---------------------------------------------
  def migrate_model!(model_class, columns, batch_size: 100)
    puts "\n▶ Migrating #{model_class.name}"

    model_class.find_each(batch_size: batch_size) do |record|
      columns.each do |old_column|
        next unless record.respond_to?(old_column)

        begin
          RichTextMigrator.new(record, old_column).migrate!
          puts "Migrated: #{model_class.name} ID=#{record.id}, column=#{old_column} "

        rescue => e
          puts "  ✖ #{model_class.name} ID=#{record.id}, column=#{old_column}: #{e.class} - #{e.message}"
        end
      end
    end

    puts "✔ #{model_class.name} complete"
  end

  # ---------------------------------------------
  # INDIVIDUAL MODEL TASKS
  # ---------------------------------------------
  # Usage:
  #   bundle exec rake rhino_migrator:resource   # single model
  #   bundle exec rake rhino_migrator:workshop  # single model
  #   bundle exec rake rhino_migrator:all       # all models
  # ---------------------------------------------

  desc "Migrate Resource text into ActionText"
  task resource: :environment do
    columns = [ :text ]
    migrate_model!(Resource, columns)
  end

  desc "Migrate Workshop text into ActionText"
  task workshop: :environment do
    columns = %i[
      objective
      materials
      optional_materials
      setup
      introduction
      opening_circle
      demonstration
      warm_up
      visualization
      creation
      closing
      notes
      tips
      misc1
      misc2
      extra_field

      objective_spanish
      materials_spanish
      optional_materials_spanish
      age_range_spanish
      setup_spanish
      introduction_spanish
      opening_circle_spanish
      demonstration_spanish
      warm_up_spanish
      visualization_spanish
      creation_spanish
      closing_spanish
      notes_spanish
      tips_spanish
      misc1_spanish
      misc2_spanish
      extra_field_spanish
    ]
    migrate_model!(Workshop, columns)
  end

  # ---------------------------------------------
  # ROLLUP TASK
  # ---------------------------------------------
  desc "Migrate all configured models into ActionText"
  task all: [ :resource, :workshop ]
end
