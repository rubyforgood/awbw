class UniqueMagicKeyEventIndex < ActiveRecord::Migration[8.1]
  def change
    remove_index :registration_ticket_callouts, column: [ :event_id, :magic_key ]
    add_index :registration_ticket_callouts, [ :event_id, :magic_key ], unique: true
  end
end
