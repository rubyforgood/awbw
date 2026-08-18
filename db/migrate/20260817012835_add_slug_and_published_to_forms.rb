class AddSlugAndPublishedToForms < ActiveRecord::Migration[8.1]
  def up
    add_column :forms, :slug, :string unless column_exists?(:forms, :slug)
    add_index :forms, :slug, unique: true unless index_exists?(:forms, :slug)
    add_column :forms, :published, :boolean, default: false, null: false unless column_exists?(:forms, :published)
  end

  def down
    remove_index :forms, :slug if index_exists?(:forms, :slug)
    remove_column :forms, :slug if column_exists?(:forms, :slug)
    remove_column :forms, :published if column_exists?(:forms, :published)
  end
end
