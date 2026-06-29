class CreateContinuingEducationRegistrations < ActiveRecord::Migration[8.1]
  def up
    create_table :continuing_education_registrations do |t|
      t.references :event_registration, null: false, foreign_key: true
      t.references :professional_license, null: false, foreign_key: true
      t.decimal :hours, precision: 5, scale: 2, null: false, default: 0
      # Total cost for this registration's CE (defaults from the event). Payment
      # state is computed from allocations, so no stored payment status.
      t.integer :cost_cents, null: false, default: 0
      # Certificate delivery timestamp (set when the certificate email is sent).
      t.datetime :certificate_sent_at
      t.bigint :created_by_id
      t.bigint :updated_by_id
      t.timestamps
    end
    add_index :continuing_education_registrations, :created_by_id
    add_index :continuing_education_registrations, :updated_by_id
  end

  def down
    drop_table :continuing_education_registrations, if_exists: true
  end
end
