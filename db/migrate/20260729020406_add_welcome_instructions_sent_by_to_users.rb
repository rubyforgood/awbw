class AddWelcomeInstructionsSentByToUsers < ActiveRecord::Migration[7.2]
  def up
    add_column :users, :welcome_instructions_sent_by_id, :integer
    add_index :users, :welcome_instructions_sent_by_id
  end

  def down
    remove_index :users, :welcome_instructions_sent_by_id, if_exists: true
    remove_column :users, :welcome_instructions_sent_by_id, if_exists: true
  end
end
