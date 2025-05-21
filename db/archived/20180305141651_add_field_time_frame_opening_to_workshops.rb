class AddFieldTimeFrameOpeningToWorkshops < ActiveRecord::Migration
  def change
     add_column :workshops, :time_opening, :integer
  end
end
