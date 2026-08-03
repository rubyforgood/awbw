class ChangeCePaymentDueDeadlineToDatetime < ActiveRecord::Migration[8.0]
  # The CE payment deadline now carries a time of day (e.g. "9:00 AM PT") so the
  # CE callout page can state exactly when payment is due, matching how the event's
  # own start/end times are stored and displayed.
  def up
    change_column :events, :ce_payment_due_deadline, :datetime
  end

  def down
    change_column :events, :ce_payment_due_deadline, :date
  end
end
