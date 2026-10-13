class CreateProfileChangeRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :profile_change_requests do |t|
      t.references :person, null: false, foreign_key: true
      t.references :requested_by, null: false, type: :integer, foreign_key: { to_table: :users }
      t.references :reviewed_by, null: true, type: :integer, foreign_key: { to_table: :users }
      t.string :field, null: false
      t.string :requested_value
      t.text :details
      t.string :status, null: false, default: "pending"
      t.string :resolution_method
      t.datetime :reviewed_at

      t.timestamps
    end

    add_index :profile_change_requests, :status
  end
end
