class RemoveFormsTicketCallouts < ActiveRecord::Migration[8.0]
  # The "forms" built-in ticket callout has been removed — the W-9 moved onto the
  # payment callout, and the invoice/receipt already live on the payment page. Any
  # rows already materialized with magic_key "forms" no longer render and would
  # fail the RegistrationTicketCallout MAGIC_KEYS inclusion validation on save, so
  # purge them.
  def up
    execute("DELETE FROM registration_ticket_callouts WHERE magic_key = 'forms'")
  end

  # Irreversible: the removed rows carried per-event admin edits we can't restore,
  # and "forms" is no longer a seedable built-in.
  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
