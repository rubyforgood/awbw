class AddViewCounterCaches < ActiveRecord::Migration[8.1]
  def change
    add_column :workshops, :view_count, :integer, default: 0, null: false
    add_column :workshop_variations, :view_count, :integer, default: 0, null: false
    add_column :resources, :view_count, :integer, default: 0, null: false
    add_column :stories, :view_count, :integer, default: 0, null: false
    add_column :community_news, :view_count, :integer, default: 0, null: false
    add_column :events, :view_count, :integer, default: 0, null: false
    add_column :quotes, :view_count, :integer, default: 0, null: false
    add_column :facilitators, :view_count, :integer, default: 0, null: false
    add_column :projects, :view_count, :integer, default: 0, null: false
    add_column :tutorials, :view_count, :integer, default: 0, null: false

    add_column :workshops, :print_count, :integer, default: 0, null: false
    add_column :resources, :print_count, :integer, default: 0, null: false
    add_column :resources, :download_count, :integer, default: 0, null: false

    add_index :workshops, :view_count
    add_index :workshop_variations, :view_count
    add_index :resources, :view_count
    add_index :stories, :view_count
    add_index :community_news, :view_count
    add_index :events, :view_count
    add_index :quotes, :view_count
    add_index :facilitators, :view_count
    add_index :projects, :view_count
    add_index :tutorials, :view_count

    add_index :workshops, :print_count
    add_index :resources, :print_count
    add_index :resources, :download_count
  end
end
