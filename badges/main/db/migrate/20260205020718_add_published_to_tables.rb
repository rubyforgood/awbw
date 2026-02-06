class AddPublishedToTables < ActiveRecord::Migration[8.1]
  TABLES = %i[
    events
    faqs
    projects
    project_obligations
    project_statuses
    quotes
    resources
    workshop_variations
    workshops

    banners
    facilitators
  ]
  # TABLES_WITH_PUBLISHED_ALREADY = %i[
  #   # categories
  #   # category_types
  #   # community_news
  #   # sectors
  #   # stories
  #   # tutorials

  # Keeping inactive
  # addresses
  # contact_methods
  # project_users
  # users

  # Removing inactive entirely
  # categorizable_items
  # sectorable_items

  # TODO
  # remove show from banners
  # add inactive to locations

  def up
    TABLES.each do |table|
      next unless table_exists?(table)
      next if column_exists?(table, :published)

      add_column table, :published, :boolean, null: false, default: false
      add_index  table, :published

      say_with_time "Backfilling #{table}.published" do
        if column_exists?(table, :inactive)
          execute <<~SQL.squish
            UPDATE #{table}
            SET published = CASE
              WHEN inactive = false THEN true
              ELSE false
            END
          SQL
        else
          # Table never had lifecycle → assume existing records are live
          execute <<~SQL.squish
            UPDATE #{table}
            SET published = true
          SQL
        end
      end
    end
  end

  def down
    TABLES.each do |table|
      next unless column_exists?(table, :published)

      remove_index table, :published if index_exists?(table, :published)
      remove_column table, :published
    end
  end
end
