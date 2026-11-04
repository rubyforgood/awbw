class DropUnusedAttachmentsAndImagesTables < ActiveRecord::Migration[8.0]
  def up
    drop_table :attachments, if_exists: true
    drop_table :images, if_exists: true
  end

  def down
    unless table_exists?(:attachments)
      create_table "attachments", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci" do |t|
        t.datetime "created_at", precision: nil, null: false
        t.integer "created_by_id"
        t.string "file_content_type"
        t.string "file_file_name"
        t.integer "file_file_size"
        t.datetime "file_updated_at", precision: nil
        t.integer "owner_id"
        t.string "owner_type"
        t.datetime "updated_at", precision: nil, null: false
        t.integer "updated_by_id"
        t.index [ "created_by_id" ], name: "index_attachments_on_created_by_id"
        t.index [ "updated_by_id" ], name: "index_attachments_on_updated_by_id"
      end
    end

    unless foreign_key_exists?(:attachments, :users, column: :created_by_id)
      add_foreign_key "attachments", "users", column: "created_by_id"
    end
    unless foreign_key_exists?(:attachments, :users, column: :updated_by_id)
      add_foreign_key "attachments", "users", column: "updated_by_id"
    end

    unless table_exists?(:images)
      create_table "images", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci" do |t|
        t.datetime "created_at", precision: nil, null: false
        t.string "file_content_type"
        t.string "file_file_name"
        t.integer "file_file_size"
        t.datetime "file_updated_at", precision: nil
        t.integer "owner_id"
        t.string "owner_type"
        t.integer "report_id"
        t.string "type", default: "Images::GalleryImage", null: false
        t.datetime "updated_at", precision: nil, null: false
        t.index [ "owner_id" ], name: "index_images_on_owner_id"
        t.index [ "type" ], name: "index_images_on_type"
      end
    end
  end
end
