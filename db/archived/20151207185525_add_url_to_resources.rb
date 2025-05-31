class AddUrlToResources < ActiveRecord::Migration[4.2]
  def change
    add_column :resources, :url, :string
  end
end
