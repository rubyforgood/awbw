class CreateRefunds < ActiveRecord::Migration[8.1]
  def change
    create_table :refunds do |t|
      t.references :refundable, polymorphic: true, null: false
      t.references :recipient, polymorphic: true, null: false
      t.integer :amount_cents, null: false
      t.timestamps
    end
  end
end
