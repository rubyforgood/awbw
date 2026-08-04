class ChangeCePaymentDueDeadlineToDatetime < ActiveRecord::Migration[8.0]
  # Now carries a time of day (e.g. 9:00 AM) so the CE callout page can state exactly when payment is due.
  def up
    change_column :events, :ce_payment_due_deadline, :datetime
  end

  def down
    change_column :events, :ce_payment_due_deadline, :date
  end
end
