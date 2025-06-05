class MakePublishedDefaultToFalseOnSectors < ActiveRecord::Migration[4.2]
  def change
    change_column :sectors, :published, :boolean, default: false
  end
end
