class AddDiscardedAtToPeopleAndUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :people, :discarded_at, :datetime unless column_exists?(:people, :discarded_at)
    add_index :people, :discarded_at unless index_exists?(:people, :discarded_at)

    add_column :users, :discarded_at, :datetime unless column_exists?(:users, :discarded_at)
    add_index :users, :discarded_at unless index_exists?(:users, :discarded_at)
  end

  def down
    remove_index :people, :discarded_at if index_exists?(:people, :discarded_at)
    remove_column :people, :discarded_at if column_exists?(:people, :discarded_at)

    remove_index :users, :discarded_at if index_exists?(:users, :discarded_at)
    remove_column :users, :discarded_at if column_exists?(:users, :discarded_at)
  end
end
