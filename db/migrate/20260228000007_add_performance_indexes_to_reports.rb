class AddPerformanceIndexesToReports < ActiveRecord::Migration[8.0]
  def change
    add_index :reports, [ :type, :organization_id ]
  end
end
