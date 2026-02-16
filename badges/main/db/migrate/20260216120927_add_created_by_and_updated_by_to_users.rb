class AddCreatedByAndUpdatedByToUsers < ActiveRecord::Migration[8.1]
  def change
    unless column_exists?(:users, :created_by_id)
      add_reference :users, :created_by, type: :integer, foreign_key: { to_table: :users }
    end
    unless column_exists?(:users, :updated_by_id)
      add_reference :users, :updated_by, type: :integer, foreign_key: { to_table: :users }
    end
  end
end
