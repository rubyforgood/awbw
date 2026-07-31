class RenameGrantApplicationDeadlineToFundsAllocationDeadline < ActiveRecord::Migration[8.1]
  def up
    rename_column :grants, :application_deadline, :funds_allocation_deadline
  end

  def down
    rename_column :grants, :funds_allocation_deadline, :application_deadline
  end
end
