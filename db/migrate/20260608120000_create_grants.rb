class CreateGrants < ActiveRecord::Migration[8.1]
  def up
    create_table :grants do |t|
      t.string :name, null: false
      t.text :description
      t.integer :amount_cents, null: false, default: 0
      t.references :donor, polymorphic: true, null: false
      t.date :application_deadline
      t.date :funds_received_on
      t.text :eligibility_criteria
      t.text :tasks
      t.bigint :created_by_id
      t.bigint :updated_by_id

      t.timestamps
    end

    add_index :grants, :created_by_id
    add_index :grants, :updated_by_id
  end

  def down
    drop_table :grants, if_exists: true
  end
end
