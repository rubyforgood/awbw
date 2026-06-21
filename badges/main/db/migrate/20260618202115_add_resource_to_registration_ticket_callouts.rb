class AddResourceToRegistrationTicketCallouts < ActiveRecord::Migration[8.1]
  def up
    # resources.id is a legacy `int` (not bigint), so the FK column must match.
    add_reference :registration_ticket_callouts, :resource, type: :integer, null: true, index: true
    add_foreign_key :registration_ticket_callouts, :resources, on_delete: :nullify
  end

  def down
    if foreign_key_exists?(:registration_ticket_callouts, :resources)
      remove_foreign_key :registration_ticket_callouts, :resources
    end
    remove_reference :registration_ticket_callouts, :resource, if_exists: true
  end
end
