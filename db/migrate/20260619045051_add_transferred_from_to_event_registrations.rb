class AddTransferredFromToEventRegistrations < ActiveRecord::Migration[8.1]
  # Links a registration created by a "Transfer" to the original it was moved
  # from, so the new event can show "Previous registration" and the old one can
  # link forward to where the registrant went.
  def up
    add_reference :event_registrations, :transferred_from, null: true, index: true
    unless foreign_key_exists?(:event_registrations, column: :transferred_from_id)
      add_foreign_key :event_registrations, :event_registrations, column: :transferred_from_id
    end
  end

  def down
    if foreign_key_exists?(:event_registrations, column: :transferred_from_id)
      remove_foreign_key :event_registrations, column: :transferred_from_id
    end
    remove_reference :event_registrations, :transferred_from, if_exists: true
  end
end
