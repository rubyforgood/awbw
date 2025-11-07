class AddBannerAuditFields < ActiveRecord::Migration[8.1]
  def change
    add_column :banners, :created_by_id, :integer, null: true
    add_column :banners, :updated_by_id, :integer, null: true

    add_index :banners, :created_by_id
    add_index :banners, :updated_by_id

    add_foreign_key :banners, :users, column: :created_by_id
    add_foreign_key :banners, :users, column: :updated_by_id
  end
end
