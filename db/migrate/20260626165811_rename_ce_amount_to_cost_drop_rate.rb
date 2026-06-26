class RenameCeAmountToCostDropRate < ActiveRecord::Migration[8.1]
  # The per-hour CE rate now lives on Event#ce_hour_cost_cents, so a CE
  # registration no longer needs its own rate column — it just snapshots the
  # total cost it bills. Rename amount_cents → cost_cents and drop rate_cents.
  def up
    rename_column :continuing_education_registrations, :amount_cents, :cost_cents if column_exists?(:continuing_education_registrations, :amount_cents)
    remove_column :continuing_education_registrations, :rate_cents, if_exists: true
  end

  def down
    add_column :continuing_education_registrations, :rate_cents, :integer, null: false, default: 2500 unless column_exists?(:continuing_education_registrations, :rate_cents)
    rename_column :continuing_education_registrations, :cost_cents, :amount_cents if column_exists?(:continuing_education_registrations, :cost_cents)
  end
end
