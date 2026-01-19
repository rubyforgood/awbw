class RemoveCounterCacheColumnsFromModels < ActiveRecord::Migration[8.1]
  def change
    # Remove view_count columns and indexes
    remove_index :community_news, name: "index_community_news_on_view_count"
    remove_column :community_news, :view_count, :integer, default: 0, null: false

    remove_index :events, name: "index_events_on_view_count"
    remove_column :events, :view_count, :integer, default: 0, null: false

    remove_index :facilitators, name: "index_facilitators_on_view_count"
    remove_column :facilitators, :view_count, :integer, default: 0, null: false

    remove_index :projects, name: "index_projects_on_view_count"
    remove_column :projects, :view_count, :integer, default: 0, null: false

    remove_index :quotes, name: "index_quotes_on_view_count"
    remove_column :quotes, :view_count, :integer, default: 0, null: false

    remove_index :stories, name: "index_stories_on_view_count"
    remove_column :stories, :view_count, :integer, default: 0, null: false

    remove_index :tutorials, name: "index_tutorials_on_view_count"
    remove_column :tutorials, :view_count, :integer, default: 0, null: false

    remove_index :workshop_variations, name: "index_workshop_variations_on_view_count"
    remove_column :workshop_variations, :view_count, :integer, default: 0, null: false

    # Remove view_count, print_count, download_count from resources
    remove_index :resources, name: "index_resources_on_view_count"
    remove_index :resources, name: "index_resources_on_print_count"
    remove_index :resources, name: "index_resources_on_download_count"
    remove_column :resources, :view_count, :integer, default: 0, null: false
    remove_column :resources, :print_count, :integer, default: 0, null: false
    remove_column :resources, :download_count, :integer, default: 0, null: false

    # Remove view_count and print_count from workshops
    remove_index :workshops, name: "index_workshops_on_view_count"
    remove_index :workshops, name: "index_workshops_on_print_count"
    remove_column :workshops, :view_count, :integer, default: 0, null: false
    remove_column :workshops, :print_count, :integer, default: 0, null: false
  end
end
