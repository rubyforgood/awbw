class AddTimetoBanner < ActiveRecord::Migration[8.1]
  def change
    add_column :banners, :started_at, :datetime
    add_column :banners, :ended_at, :datetime
  end
end
