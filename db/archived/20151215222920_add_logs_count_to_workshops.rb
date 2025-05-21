class AddLogsCountToWorkshops < ActiveRecord::Migration
  def change
    add_column :workshops, :led_count, :integer, default: 0
  end
end
