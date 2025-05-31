class AddPublishedToSectors < ActiveRecord::Migration[4.2]
  def change
    add_column :sectors, :published, :boolean, default: false
  end
end
