class AddShortDescriptionToEvents < ActiveRecord::Migration[8.1]
  def up
    add_column :events, :short_description, :text
  end

  def down
    remove_column :events, :short_description, if_exists: true
  end
end
