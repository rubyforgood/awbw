class AddPublishedToSectors < ActiveRecord::Migration
  def change
    add_column :sectors, :published, :boolean, default: false
  end
end
