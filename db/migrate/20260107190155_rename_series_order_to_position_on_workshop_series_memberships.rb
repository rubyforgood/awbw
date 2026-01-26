class RenameSeriesOrderToPositionOnWorkshopSeriesMemberships < ActiveRecord::Migration[8.1]
  def change
    rename_column :workshop_series_memberships, :series_order, :position
  end
end
