class AddProfileShowResourcesToPeople < ActiveRecord::Migration[8.1]
  def up
    return if column_exists?(:people, :profile_show_resources)
    add_column :people, :profile_show_resources, :boolean, default: true, null: false
  end

  def down
    remove_column :people, :profile_show_resources, if_exists: true
  end
end
