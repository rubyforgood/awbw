class RenameEventCeFields < ActiveRecord::Migration[8.1]
  # Pivot the event CE fields onto stored values rather than a per-hour rate that
  # gets multiplied out: ce_hours -> ce_hours_offered (the decimal hours of CE
  # credit offered) and ce_hour_cost_cents -> ce_hours_cost_cents (total CE cost).
  def up
    rename_column :events, :ce_hours, :ce_hours_offered if column_exists?(:events, :ce_hours)
    rename_column :events, :ce_hour_cost_cents, :ce_hours_cost_cents if column_exists?(:events, :ce_hour_cost_cents)
  end

  def down
    rename_column :events, :ce_hours_offered, :ce_hours if column_exists?(:events, :ce_hours_offered)
    rename_column :events, :ce_hours_cost_cents, :ce_hour_cost_cents if column_exists?(:events, :ce_hours_cost_cents)
  end
end
