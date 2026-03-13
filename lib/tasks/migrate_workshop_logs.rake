namespace :workshop_logs do
  desc "Migrate WorkshopLog data from reports table to workshop_logs table"
  task migrate_from_reports: :environment do
    wl_condition = "type = 'WorkshopLog'"

    ActiveRecord::Base.transaction do
      # Clear legacy test data from the transformed table
      count = ActiveRecord::Base.connection.execute("SELECT COUNT(*) AS c FROM workshop_logs").first
      if count && count[0] > 0
        puts "Clearing #{count[0]} legacy record(s) from workshop_logs..."
        ActiveRecord::Base.connection.execute("UPDATE report_form_field_answers SET workshop_log_id = NULL WHERE workshop_log_id IS NOT NULL")
        ActiveRecord::Base.connection.execute("DELETE FROM workshop_logs")
      end

      # Copy WorkshopLog records from reports, preserving IDs
      workshop_log_count = ActiveRecord::Base.connection.execute(
        "SELECT COUNT(*) AS c FROM reports WHERE #{wl_condition}"
      ).first[0]
      # Reassign orphaned created_by_id to the "Orphaned Reports" user
      orphaned_user = User.find_by!(email: "orphaned_reports@awbw.org")
      orphan_count = ActiveRecord::Base.connection.execute(
        "SELECT COUNT(*) FROM reports r LEFT JOIN users u ON u.id = r.created_by_id WHERE r.#{wl_condition} AND r.created_by_id IS NOT NULL AND u.id IS NULL"
      ).first[0]
      puts "Copying #{workshop_log_count} WorkshopLog records to workshop_logs table..."
      puts "  (#{orphan_count} records have orphaned created_by_id — reassigning to #{orphaned_user.email})" if orphan_count > 0

      ActiveRecord::Base.connection.execute(<<~SQL)
        INSERT INTO workshop_logs (
          id, created_by_id, organization_id, windows_type_id, workshop_id,
          workshop_held_on, rating, external_workshop_title,
          children_first_time, children_ongoing,
          teens_first_time, teens_ongoing, adults_first_time, adults_ongoing,
          created_at, updated_at
        )
        SELECT
          r.id,
          CASE WHEN u.id IS NOT NULL THEN r.created_by_id ELSE #{orphaned_user.id} END,
          r.organization_id, r.windows_type_id, r.workshop_id,
          r.date, r.rating, COALESCE(r.external_workshop_title, r.workshop_name),
          r.children_first_time, r.children_ongoing,
          r.teens_first_time, r.teens_ongoing, r.adults_first_time, r.adults_ongoing,
          r.created_at, r.updated_at
        FROM reports r
        LEFT JOIN users u ON u.id = r.created_by_id
        WHERE r.#{wl_condition}
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

      # Populate total columns from migrated attendance data
      puts "Populating total_children, total_teens, total_adults..."
      ActiveRecord::Base.connection.execute(<<~SQL)
        UPDATE workshop_logs
        SET total_children = COALESCE(children_first_time, 0) + COALESCE(children_ongoing, 0),
            total_teens = COALESCE(teens_first_time, 0) + COALESCE(teens_ongoing, 0),
            total_adults = COALESCE(adults_first_time, 0) + COALESCE(adults_ongoing, 0)
      SQL

      puts "Done! #{workshop_log_count} workshop logs migrated successfully."
    end
  end

  desc "Delete WorkshopLog records from reports table (run after migrate_from_reports)"
  task delete_from_reports: :environment do
    wl_condition = "type = 'WorkshopLog'"

    wl_count = ActiveRecord::Base.connection.execute(
      "SELECT COUNT(*) FROM workshop_logs"
    ).first[0]
    report_count = ActiveRecord::Base.connection.execute(
      "SELECT COUNT(*) FROM reports WHERE #{wl_condition}"
    ).first[0]

    if wl_count == 0
      abort "No records in workshop_logs — run `rake workshop_logs:migrate_from_reports` first."
    end

    if report_count == 0
      puts "No WorkshopLog records in reports table. Nothing to delete."
      next
    end

    puts "workshop_logs table: #{wl_count} records"
    puts "reports table (WorkshopLog): #{report_count} records"
    puts "Deleting #{report_count} WorkshopLog records from reports..."

    ActiveRecord::Base.connection.execute(<<~SQL)
      DELETE FROM reports WHERE #{wl_condition}
    SQL

    puts "Done! Deleted #{report_count} WorkshopLog records from reports table."
  end
end
