class AddFavoriteEventToUsers < ActiveRecord::Migration[8.1]
  # Lets admins pin a "favorite" event to a user account so it can be surfaced
  # as a quick "My favorite event" shortcut in the user nav. Nullable, so an
  # unset value simply renders no shortcut.
  def up
    unless column_exists?(:users, :favorite_event_id)
      add_column :users, :favorite_event_id, :bigint
      add_index :users, :favorite_event_id
      add_foreign_key :users, :events, column: :favorite_event_id
    end
  end

  def down
    remove_foreign_key :users, column: :favorite_event_id if foreign_key_exists?(:users, column: :favorite_event_id)
    remove_index :users, :favorite_event_id, if_exists: true
    remove_column :users, :favorite_event_id, if_exists: true
  end
end
