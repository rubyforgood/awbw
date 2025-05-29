class AddWorkshopNameToWorkshopLogs < ActiveRecord::Migration[4.2]
  def change
    add_column :reports, :workshop_name, :string
  end
end
