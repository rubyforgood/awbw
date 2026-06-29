class AddCeHoursFieldsToEvents < ActiveRecord::Migration[8.1]
  def up
    # ce_hours is how many (fractional) hours of CE credit a registrant can earn
    # by attending. Distinct from the existing ce_hours_details copy, which is
    # display-only. Eligibility is derived from this value, not a separate flag.
    add_column :events, :ce_hours, :decimal, precision: 5, scale: 2
  end

  def down
    remove_column :events, :ce_hours, if_exists: true
  end
end
