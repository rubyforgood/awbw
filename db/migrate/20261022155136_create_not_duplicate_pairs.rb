class CreateNotDuplicatePairs < ActiveRecord::Migration[8.1]
  def up
    create_table :not_duplicate_pairs do |t|
      t.string :record_type, null: false
      t.bigint :first_record_id, null: false
      t.bigint :second_record_id, null: false
      t.integer :created_by_id
      t.timestamps
    end

    add_index :not_duplicate_pairs, %i[record_type first_record_id second_record_id], unique: true,
      name: "index_not_duplicate_pairs_on_type_and_records"
    add_index :not_duplicate_pairs, %i[record_type second_record_id]
    add_index :not_duplicate_pairs, :created_by_id
    add_foreign_key :not_duplicate_pairs, :users, column: :created_by_id
  end

  def down
    drop_table :not_duplicate_pairs, if_exists: true
  end
end
