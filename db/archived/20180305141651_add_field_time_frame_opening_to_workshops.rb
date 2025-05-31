class AddFieldTimeFrameOpeningToWorkshops < ActiveRecord::Migration[4.2]
  def change
     add_column :workshops, :time_opening, :integer
  end
end
