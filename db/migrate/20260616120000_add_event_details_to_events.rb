class AddEventDetailsToEvents < ActiveRecord::Migration[8.1]
  def up
    add_column :events, :event_details, :text
    add_column :events, :event_details_label, :string, default: "Before you attend", null: false
  end

  def down
    remove_column :events, :event_details, if_exists: true
    remove_column :events, :event_details_label, if_exists: true
  end
end
