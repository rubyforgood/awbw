class AddCredentialsToPeople < ActiveRecord::Migration[8.1]
  def up
    add_column :people, :credentials, :string unless column_exists?(:people, :credentials)

    unless column_exists?(:people, :profile_show_credentials)
      add_column :people, :profile_show_credentials, :boolean, default: true, null: false
    end
  end

  def down
    remove_column :people, :profile_show_credentials, if_exists: true
    remove_column :people, :credentials, if_exists: true
  end
end
