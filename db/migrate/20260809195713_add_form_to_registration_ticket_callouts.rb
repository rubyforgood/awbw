class AddFormToRegistrationTicketCallouts < ActiveRecord::Migration[8.1]
  # The survey form a callout delivers inline (post-event survey callouts). Nullable —
  # ordinary callouts have no form. Integer FK to match the forms table's integer PK.
  def up
    return if column_exists?(:registration_ticket_callouts, :form_id)
    add_reference :registration_ticket_callouts, :form, type: :integer, foreign_key: true, null: true
  end

  def down
    return unless column_exists?(:registration_ticket_callouts, :form_id)
    remove_reference :registration_ticket_callouts, :form, foreign_key: true
  end
end
