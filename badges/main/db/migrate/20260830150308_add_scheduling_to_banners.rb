class AddSchedulingToBanners < ActiveRecord::Migration[8.1]
  def up
    add_column :banners, :started_at, :datetime
    add_column :banners, :ended_at, :datetime
  end

  def down
    remove_column :banners, :started_at, if_exists: true
    remove_column :banners, :ended_at, if_exists: true
  end
end
