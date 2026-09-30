class DropLegacyAttachmentTables < ActiveRecord::Migration[8.1]
  def up
    ensure_media_files_backfilled!

    drop_table :ckeditor_assets, if_exists: true
    drop_table :attachments, if_exists: true
    drop_table :images, if_exists: true
    drop_table :media_files, if_exists: true
  end

  def down
    create_table :ckeditor_assets, id: :integer do |t|
      t.string :actual_url
      t.integer :assetable_id
      t.string :assetable_type, limit: 30
      t.datetime :created_at, precision: nil, null: false
      t.string :data_content_type
      t.string :data_file_name, null: false
      t.integer :data_file_size
      t.integer :height
      t.string :type, limit: 30
      t.datetime :updated_at, precision: nil, null: false
      t.integer :width
      t.index [ :assetable_type, :assetable_id ], name: "idx_ckeditor_assetable"
      t.index [ :assetable_type, :type, :assetable_id ], name: "idx_ckeditor_assetable_type"
    end

    create_table :attachments, id: :integer do |t|
      t.datetime :created_at, precision: nil, null: false
      t.integer :created_by_id
      t.string :file_content_type
      t.string :file_file_name
      t.integer :file_file_size
      t.datetime :file_updated_at, precision: nil
      t.integer :owner_id
      t.string :owner_type
      t.datetime :updated_at, precision: nil, null: false
      t.integer :updated_by_id
      t.index [ :created_by_id ], name: "index_attachments_on_created_by_id"
      t.index [ :updated_by_id ], name: "index_attachments_on_updated_by_id"
    end

    create_table :images, id: :integer do |t|
      t.datetime :created_at, precision: nil, null: false
      t.string :file_content_type
      t.string :file_file_name
      t.integer :file_file_size
      t.datetime :file_updated_at, precision: nil
      t.integer :owner_id
      t.string :owner_type
      t.integer :report_id
      t.string :type, default: "Images::GalleryImage", null: false
      t.datetime :updated_at, precision: nil, null: false
      t.index [ :owner_id ], name: "index_images_on_owner_id"
      t.index [ :type ], name: "index_images_on_type"
    end

    create_table :media_files, id: :integer do |t|
      t.integer :created_by_id
      t.string :file_content_type
      t.string :file_file_name
      t.integer :file_file_size
      t.datetime :file_updated_at, precision: nil
      t.integer :report_id
      t.integer :updated_by_id
      t.integer :workshop_log_id
      t.index [ :created_by_id ], name: "index_media_files_on_created_by_id"
      t.index [ :updated_by_id ], name: "index_media_files_on_updated_by_id"
    end
  end

  # Refuse to drop media_files until every report-scoped row's upload has been
  # moved onto a GalleryAsset, so auto-migration can't silently lose files.
  def ensure_media_files_backfilled!
    return unless table_exists?(:media_files)

    remaining = select_value(<<~SQL).to_i
      SELECT COUNT(*)
      FROM active_storage_attachments asa
      JOIN media_files mf ON mf.id = asa.record_id
      WHERE asa.record_type = 'MediaFile'
        AND asa.name = 'file'
        AND mf.report_id IS NOT NULL
    SQL

    return if remaining.zero?

    raise "#{remaining} report media_files still hold an attachment. " \
          "Run `rake media_files:migrate_to_gallery_assets` before migrating."
  end
end
