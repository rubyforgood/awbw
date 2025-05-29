class ChangeResourceTypeColumn < ActiveRecord::Migration[4.2]
  def change
    rename_column :resources, :type, :kind
  end
end
