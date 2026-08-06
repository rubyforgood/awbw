class AddOnDemandToEvents < ActiveRecord::Migration[8.0]
  # Flags a facilitator-training event as on-demand (self-paced) rather than a
  # scheduled multi-day session. Used by the facilitator-training report to split
  # trainee counts into "2-Day" vs "On-Demand" totals. Defaults false so existing
  # events read as scheduled sessions.
  def up
    return if column_exists?(:events, :on_demand)
    add_column :events, :on_demand, :boolean, default: false, null: false
  end

  def down
    remove_column :events, :on_demand, if_exists: true
  end
end
