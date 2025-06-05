class OtherDescriptionToWorkshopLogs < ActiveRecord::Migration[4.2]
  def change
    add_column :reports, :other_description, :string
  end
end
