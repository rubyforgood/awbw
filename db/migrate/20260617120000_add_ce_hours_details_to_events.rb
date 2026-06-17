class AddCeHoursDetailsToEvents < ActiveRecord::Migration[8.1]
  def up
    add_column :events, :ce_hours_details, :text
    add_column :events, :ce_hours_details_label, :string, default: "CE hours", null: false
  end

  def down
    remove_column :events, :ce_hours_details, if_exists: true
    remove_column :events, :ce_hours_details_label, if_exists: true
  end
end
