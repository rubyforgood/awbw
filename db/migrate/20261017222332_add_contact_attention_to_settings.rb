class AddContactAttentionToSettings < ActiveRecord::Migration[8.1]
  def up
    add_column :settings, :contact_attention, :string unless column_exists?(:settings, :contact_attention)
  end

  def down
    remove_column :settings, :contact_attention, if_exists: true
  end
end
