class AddExternalWorkshopTitleToReports < ActiveRecord::Migration[8.1]
  def change
    add_column :reports, :external_workshop_title, :string
  end
end
