class AddFeaturedToEvent < ActiveRecord::Migration[8.1]
  def change
    add_column :events, :featured, :boolean, null: false, default: false
  end
end
