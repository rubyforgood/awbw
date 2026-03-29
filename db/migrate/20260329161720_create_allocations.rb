class CreateAllocations < ActiveRecord::Migration[8.1]
  def change
    create_table :allocations do |t|
      t.references :source, polymorphic: true, null: false
      t.references :allocatable, polymorphic: true, null: false
      t.integer :amount, null: false, default: 0
      t.timestamps
    end
    add_index :allocations, [ :source_type, :source_id ]
    add_index :allocations, [ :allocatable_type, :allocatable_id ]
  end
end
