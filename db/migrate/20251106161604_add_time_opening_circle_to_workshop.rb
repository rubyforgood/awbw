class AddTimeOpeningCircleToWorkshop < ActiveRecord::Migration[8.1]
  def change
    add_column :workshops, :time_opening_circle, :integer
  end
end
