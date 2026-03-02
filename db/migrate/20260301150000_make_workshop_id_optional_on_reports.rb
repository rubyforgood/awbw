class MakeWorkshopIdOptionalOnReports < ActiveRecord::Migration[8.1]
  def change
    change_column_null :reports, :workshop_id, true
  end
end
