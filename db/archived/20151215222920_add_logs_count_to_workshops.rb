class AddLogsCountToWorkshops < ActiveRecord::Migration[4.2]
  def change
    add_column :workshops, :led_count, :integer, default: 0
  end
end
