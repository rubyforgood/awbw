class AddRatingToReports < ActiveRecord::Migration
  def change
    add_column :reports, :rating, :integer, default: 0
  end
end
