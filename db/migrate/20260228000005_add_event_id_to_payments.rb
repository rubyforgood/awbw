class AddEventIdToPayments < ActiveRecord::Migration[8.1]
  def change
    unless column_exists?(:payments, :event_id)
      add_reference :payments, :event, null: true, foreign_key: true
    end
  end
end
