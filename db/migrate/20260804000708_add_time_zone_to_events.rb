class AddTimeZoneToEvents < ActiveRecord::Migration[8.1]
  def up
    add_column :events, :time_zone, :string, null: false, default: "Pacific Time (US & Canada)"
  end

  def down
    remove_column :events, :time_zone, if_exists: true
  end
end
