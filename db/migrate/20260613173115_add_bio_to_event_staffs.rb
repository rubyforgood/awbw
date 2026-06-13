class AddBioToEventStaffs < ActiveRecord::Migration[8.1]
  def up
    add_column :event_staffs, :bio, :text
  end

  def down
    remove_column :event_staffs, :bio, if_exists: true
  end
end
