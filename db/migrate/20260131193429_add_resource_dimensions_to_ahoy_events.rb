class AddResourceDimensionsToAhoyEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :ahoy_events, :resource_type, :string
    add_column :ahoy_events, :resource_id, :bigint

    add_index :ahoy_events, [:resource_type, :resource_id, :time]
    add_index :ahoy_events, :resource_id
  end
end
