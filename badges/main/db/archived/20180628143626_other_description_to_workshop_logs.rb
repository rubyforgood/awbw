class OtherDescriptionToWorkshopLogs < ActiveRecord::Migration
  def change
    add_column :reports, :other_description, :string
  end
end
