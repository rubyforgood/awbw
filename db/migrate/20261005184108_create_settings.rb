class CreateSettings < ActiveRecord::Migration[8.1]
  # One row of app-wide settings. `singleton` is a constant true with a unique
  # index, which is how MySQL enforces "only ever one row" without a CHECK.
  def up
    return if table_exists?(:settings)

    create_table :settings do |t|
      t.boolean :singleton, null: false, default: true
      # :integer, not the :bigint a references would give — organizations.id is int.
      t.integer :organization_id
      t.string :info_email
      t.string :reply_to_email
      t.string :programs_email
      t.string :no_reply_email
      t.text :organization_address
      t.text :remittance_address
      t.string :invoice_prefix
      t.integer :annual_membership_cents
      t.integer :membership_renewal_window_days
      t.integer :membership_grace_period_days
      t.integer :created_by_id
      t.integer :updated_by_id
      t.timestamps
    end

    add_index :settings, :singleton, unique: true
    add_index :settings, :organization_id
    add_foreign_key :settings, :organizations
    add_index :settings, :created_by_id
    add_index :settings, :updated_by_id
  end

  def down
    drop_table :settings, if_exists: true
  end
end
