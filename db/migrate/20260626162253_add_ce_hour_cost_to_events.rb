class AddCeHourCostToEvents < ActiveRecord::Migration[8.1]
  # Per-event override of the CE per-hour price, in cents (mirrors cost_cents).
  # Left nullable with no DB default so a nil means "use the standard rate" —
  # Event#ce_hour_cost_cents falls back to the default hourly rate.
  def up
    add_column :events, :ce_hour_cost_cents, :integer unless column_exists?(:events, :ce_hour_cost_cents)
  end

  def down
    remove_column :events, :ce_hour_cost_cents, if_exists: true
  end
end
