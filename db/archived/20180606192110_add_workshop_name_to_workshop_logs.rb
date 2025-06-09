class AddWorkshopNameToWorkshopLogs < ActiveRecord::Migration
  def change
    add_column :reports, :workshop_name, :string
  end
end
