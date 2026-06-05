class AddRevertedIdToAllocations < ActiveRecord::Migration[8.1]
  def change
    add_column :allocations, :reverted_id, :bigint
    add_foreign_key :allocations, :allocations, column: :reverted_id, primary_key: :id, validate: false
  end
end
