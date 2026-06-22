class AddCeCreditsEligibleToEvents < ActiveRecord::Migration[8.1]
  def up
    add_column :events, :ce_credits_eligible, :boolean, default: true, null: false
  end

  def down
    remove_column :events, :ce_credits_eligible, if_exists: true
  end
end
