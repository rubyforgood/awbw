class AddCreatedAtIndexToComments < ActiveRecord::Migration[8.1]
  def up
    add_index :comments, :created_at, if_not_exists: true
  end

  def down
    remove_index :comments, :created_at, if_exists: true
  end
end
