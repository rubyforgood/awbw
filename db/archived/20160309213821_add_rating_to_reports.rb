class AddRatingToReports < ActiveRecord::Migration[4.2]
  def change
    add_column :reports, :rating, :integer, default: 0
  end
end
