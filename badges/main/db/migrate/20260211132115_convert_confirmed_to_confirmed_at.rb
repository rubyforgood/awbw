class ConvertConfirmedToConfirmedAt < ActiveRecord::Migration[8.1]
  class MigrationUser < ApplicationRecord
    self.table_name = "users"
  end

  def up
    # Only backfill where confirmed was true AND confirmed_at is missing
    MigrationUser
      .where(confirmed: true, confirmed_at: nil)
      .update_all("confirmed_at = updated_at")

    remove_column :users, :confirmed, :boolean
  end

  def down
    add_column :users, :confirmed, :boolean, default: false unless column_exists?(:users, :confirmed)

    MigrationUser
      .where.not(confirmed_at: nil)
      .update_all("confirmed = true")
  end
end
