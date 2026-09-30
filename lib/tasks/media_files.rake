namespace :media_files do
  desc "Convert report media_files into GalleryAssets, moving their attachments (idempotent)"
  task migrate_to_gallery_assets: :environment do
    rows = ActiveRecord::Base.connection.select_all(<<~SQL)
      SELECT id, report_id, created_by_id, updated_by_id
      FROM media_files
      WHERE report_id IS NOT NULL
    SQL

    migrated = 0
    skipped_no_file = 0

    rows.each do |row|
      attachment = ActiveStorage::Attachment.find_by(
        record_type: "MediaFile", record_id: row["id"], name: "file"
      )
      unless attachment
        skipped_no_file += 1
        next
      end

      asset = GalleryAsset.create!(
        owner_type: "Report",
        owner_id: row["report_id"],
        created_by_id: row["created_by_id"],
        updated_by_id: row["updated_by_id"]
      )
      # update_columns to skip the touch callback, which would constantize the
      # old "MediaFile" record_type after that model has been removed.
      attachment.update_columns(record_type: "Asset", record_id: asset.id)
      migrated += 1
    end

    puts "media_files → gallery_assets: #{migrated} migrated, #{skipped_no_file} without a file skipped."
  end

  desc "Report how many report media_files still hold their own attachment (pre-drop check)"
  task status: :environment do
    total = ActiveRecord::Base.connection.select_value(
      "SELECT COUNT(*) FROM media_files WHERE report_id IS NOT NULL"
    ).to_i

    remaining = ActiveStorage::Attachment
      .where(record_type: "MediaFile", name: "file")
      .where("record_id IN (SELECT id FROM media_files WHERE report_id IS NOT NULL)")
      .count

    if remaining.zero?
      puts "✅ Backfill complete: 0 of #{total} report media_files still hold an attachment. Safe to drop media_files."
    else
      puts "⚠️  #{remaining} of #{total} report media_files still hold an attachment. " \
           "Run `rake media_files:migrate_to_gallery_assets` first."
    end
  end
end
