class RemoveCredentialsFromPeople < ActiveRecord::Migration[8.1]
  # The free-text credentials field is no longer edited or displayed — the profile
  # credential suffix now derives from the person's professional-license types
  # (Person#license_credentials). The profile_show_credentials toggle stays.
  def up
    remove_column :people, :credentials, if_exists: true
  end

  def down
    add_column :people, :credentials, :string unless column_exists?(:people, :credentials)
  end
end
