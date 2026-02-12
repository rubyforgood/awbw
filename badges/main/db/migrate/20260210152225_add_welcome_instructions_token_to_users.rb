class AddWelcomeInstructionsTokenToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :welcome_instructions_token, :string
    add_column :users, :welcome_instructions_created_at, :datetime
    add_column :users, :welcome_instructions_sent_at, :datetime
    add_index :users, :welcome_instructions_token, unique: true
  end
end
