class AddDateToReports < ActiveRecord::Migration
  def change
    add_column :reports, :date, :date
  end
end
