class MakePublishedDefaultToFalseOnSectors < ActiveRecord::Migration
  def change
    change_column :sectors, :published, :boolean, default: false
  end
end
