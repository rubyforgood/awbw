class AddCeHoursFieldsToEvents < ActiveRecord::Migration[8.1]
  def up
    # ce_hours_eligible is the explicit "this training grants CE" gate; ce_hours
    # is how many (fractional) hours a registrant can earn. Distinct from the
    # existing ce_hours_details copy, which is display-only.
    add_column :events, :ce_hours_eligible, :boolean, null: false, default: false
    add_column :events, :ce_hours, :decimal, precision: 5, scale: 2
  end

  def down
    remove_column :events, :ce_hours_eligible, if_exists: true
    remove_column :events, :ce_hours, if_exists: true
  end
end
