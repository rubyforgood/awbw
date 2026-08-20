class AddCeHoursFieldsToEvents < ActiveRecord::Migration[8.1]
  def up
    # ce_hours_offered: how many (fractional) hours of CE credit a registrant can
    # earn by attending. Distinct from the display-only ce_hours_details copy.
    # Eligibility is derived from this value (> 0), not a separate flag.
    # ce_hours_cost_cents: the total price charged for those CE hours.
    add_column :events, :ce_hours_offered, :decimal, precision: 5, scale: 2
    add_column :events, :ce_hours_cost_cents, :integer
  end

  def down
    remove_column :events, :ce_hours_offered, if_exists: true
    remove_column :events, :ce_hours_cost_cents, if_exists: true
  end
end
