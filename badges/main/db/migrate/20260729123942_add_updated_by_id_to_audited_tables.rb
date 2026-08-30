class AddUpdatedByIdToAuditedTables < ActiveRecord::Migration[8.1]
  # Tables that already stamp created_by_id but have no matching updated_by_id. With
  # these columns the UserStampable concern records the last editor on every update.
  # reports covers MonthlyReport (STI on reports).
  TABLES = %i[reports workshop_logs workshop_variations resources workshops events].freeze

  def up
    TABLES.each do |table|
      add_column table, :updated_by_id, :integer, null: true unless column_exists?(table, :updated_by_id)
      add_index table, :updated_by_id unless index_exists?(table, :updated_by_id)
      add_foreign_key table, :users, column: :updated_by_id unless foreign_key_exists?(table, :users, column: :updated_by_id)
    end
  end

  def down
    TABLES.each do |table|
      remove_foreign_key table, :users, column: :updated_by_id if foreign_key_exists?(table, :users, column: :updated_by_id)
      remove_index table, :updated_by_id if index_exists?(table, :updated_by_id)
      remove_column table, :updated_by_id if column_exists?(table, :updated_by_id)
    end
  end
end
