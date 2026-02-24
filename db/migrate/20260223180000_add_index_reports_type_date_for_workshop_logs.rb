class AddIndexReportsTypeDateForWorkshopLogs < ActiveRecord::Migration[8.0]
  def change
    add_index :reports, [ :type, :date ], name: "index_reports_on_type_and_date"
    add_index :reports, :workshop_id, name: "index_reports_on_workshop_id"
  end
end
