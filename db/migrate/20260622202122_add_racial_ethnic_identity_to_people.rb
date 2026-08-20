class AddRacialEthnicIdentityToPeople < ActiveRecord::Migration[8.1]
  def up
    add_column :people, :racial_ethnic_identity, :string
  end

  def down
    remove_column :people, :racial_ethnic_identity, if_exists: true
  end
end
