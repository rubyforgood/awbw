namespace :workshop_logs do
  desc "Migrate WorkshopLog data from reports table to workshop_logs table"
  task migrate_from_reports: :environment do
    wl_condition = "type = 'WorkshopLog'"

    ActiveRecord::Base.transaction do
      # Clear legacy test data from the transformed table
      count = ActiveRecord::Base.connection.execute("SELECT COUNT(*) AS c FROM workshop_logs").first
      if count && count[0] > 0
        puts "Clearing #{count[0]} legacy record(s) from workshop_logs..."
        ActiveRecord::Base.connection.execute("DELETE FROM workshop_logs")
      end

      # Copy WorkshopLog records from reports, preserving IDs
      workshop_log_count = ActiveRecord::Base.connection.execute(
        "SELECT COUNT(*) AS c FROM reports WHERE #{wl_condition}"
      ).first[0]
      puts "Copying #{workshop_log_count} WorkshopLog records to workshop_logs table..."

      ActiveRecord::Base.connection.execute(<<~SQL)
        INSERT INTO workshop_logs (
          id, created_by_id, organization_id, windows_type_id, workshop_id,
          date, rating, external_workshop_title, workshop_name,
          other_description, children_first_time, children_ongoing,
          teens_first_time, teens_ongoing, adults_first_time, adults_ongoing,
          created_at, updated_at
        )
        SELECT
          id, created_by_id, organization_id, windows_type_id, workshop_id,
          date, rating, external_workshop_title, workshop_name,
          other_description, children_first_time, children_ongoing,
          teens_first_time, teens_ongoing, adults_first_time, adults_ongoing,
          created_at, updated_at
        FROM reports
        WHERE #{wl_condition}
      SQL

      # Update report_form_field_answers to point to workshop_logs
      rffa_count = ActiveRecord::Base.connection.execute(<<~SQL).first[0]
        SELECT COUNT(*) FROM report_form_field_answers
        WHERE report_id IN (SELECT id FROM reports WHERE #{wl_condition})
      SQL
      puts "Updating #{rffa_count} report_form_field_answers..."
      ActiveRecord::Base.connection.execute(<<~SQL)
        UPDATE report_form_field_answers
        SET workshop_log_id = report_id, report_id = NULL
        WHERE report_id IN (SELECT id FROM reports WHERE #{wl_condition})
      SQL

      # Update active_storage_attachments record_type
      asa_count = ActiveRecord::Base.connection.execute(<<~SQL).first[0]
        SELECT COUNT(*) FROM active_storage_attachments
        WHERE record_type = 'Report'
          AND record_id IN (SELECT id FROM reports WHERE #{wl_condition})
      SQL
      puts "Updating #{asa_count} active_storage_attachments..."
      ActiveRecord::Base.connection.execute(<<~SQL)
        UPDATE active_storage_attachments
        SET record_type = 'WorkshopLog'
        WHERE record_type = 'Report'
          AND record_id IN (SELECT id FROM reports WHERE #{wl_condition})
      SQL

      # Update assets with polymorphic owner
      assets_count = ActiveRecord::Base.connection.execute(<<~SQL).first[0]
        SELECT COUNT(*) FROM assets
        WHERE owner_type = 'Report'
          AND owner_id IN (SELECT id FROM reports WHERE #{wl_condition})
      SQL
      puts "Updating #{assets_count} assets..."
      ActiveRecord::Base.connection.execute(<<~SQL)
        UPDATE assets
        SET owner_type = 'WorkshopLog'
        WHERE owner_type = 'Report'
          AND owner_id IN (SELECT id FROM reports WHERE #{wl_condition})
      SQL

      # Fix quotable_item_quotes stored as type 'Report' for WorkshopLog records
      qiq_count = ActiveRecord::Base.connection.execute(<<~SQL).first[0]
        SELECT COUNT(*) FROM quotable_item_quotes
        WHERE quotable_type = 'Report'
          AND quotable_id IN (SELECT id FROM reports WHERE #{wl_condition})
      SQL
      puts "Updating #{qiq_count} quotable_item_quotes..."
      ActiveRecord::Base.connection.execute(<<~SQL)
        UPDATE quotable_item_quotes
        SET quotable_type = 'WorkshopLog'
        WHERE quotable_type = 'Report'
          AND quotable_id IN (SELECT id FROM reports WHERE #{wl_condition})
      SQL

      # Update sectorable_items polymorphic type
      si_count = ActiveRecord::Base.connection.execute(<<~SQL).first[0]
        SELECT COUNT(*) FROM sectorable_items
        WHERE sectorable_type = 'Report'
          AND sectorable_id IN (SELECT id FROM reports WHERE #{wl_condition})
      SQL
      puts "Updating #{si_count} sectorable_items..."
      ActiveRecord::Base.connection.execute(<<~SQL)
        UPDATE sectorable_items
        SET sectorable_type = 'WorkshopLog'
        WHERE sectorable_type = 'Report'
          AND sectorable_id IN (SELECT id FROM reports WHERE #{wl_condition})
      SQL

      # Delete WorkshopLog records from reports table
      puts "Deleting WorkshopLog records from reports table..."
      ActiveRecord::Base.connection.execute(<<~SQL)
        DELETE FROM reports WHERE #{wl_condition}
      SQL

      # Populate total columns from migrated attendance data
      puts "Populating total_children, total_teens, total_adults..."
      ActiveRecord::Base.connection.execute(<<~SQL)
        UPDATE workshop_logs
        SET total_children = COALESCE(children_first_time, 0) + COALESCE(children_ongoing, 0),
            total_teens = COALESCE(teens_first_time, 0) + COALESCE(teens_ongoing, 0),
            total_adults = COALESCE(adults_first_time, 0) + COALESCE(adults_ongoing, 0)
      SQL

      # Enforce NOT NULL on columns that are always populated
      puts "Enforcing NOT NULL constraints..."
      ActiveRecord::Base.connection.execute("ALTER TABLE workshop_logs MODIFY organization_id int NOT NULL")
      ActiveRecord::Base.connection.execute("ALTER TABLE workshop_logs MODIFY windows_type_id int NOT NULL")

      puts "Done! #{workshop_log_count} workshop logs migrated successfully."
    end
  end
end
