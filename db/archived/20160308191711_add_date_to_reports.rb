class AddDateToReports < ActiveRecord::Migration[4.2]
  def change
    add_column :reports, :date, :date
  end
end
