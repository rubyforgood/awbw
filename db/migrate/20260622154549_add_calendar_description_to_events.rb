class AddCalendarDescriptionToEvents < ActiveRecord::Migration[8.1]
  def up
    add_column :events, :calendar_description, :text
  end

  def down
    remove_column :events, :calendar_description, if_exists: true
  end
end
