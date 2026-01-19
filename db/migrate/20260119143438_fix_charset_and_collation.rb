class FixCharsetAndCollation < ActiveRecord::Migration[8.1]
  DB = ActiveRecord::Base.connection_db_config.database
  TARGET = "utf8mb4"
  COLL = "utf8mb4_unicode_ci"

  def up
    execute "ALTER DATABASE `#{DB}` CHARACTER SET #{TARGET} COLLATE #{COLL}"
    tables.each do |t|
      execute "ALTER TABLE `#{t}` CONVERT TO CHARACTER SET #{TARGET} COLLATE #{COLL}"
    end
  end

  def down
    # no-op (irreversible)
  end

  private

  def tables
    ActiveRecord::Base.connection.tables - [ "schema_migrations", "ar_internal_metadata" ]
  end
end
