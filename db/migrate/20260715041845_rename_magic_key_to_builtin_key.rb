class RenameMagicKeyToBuiltinKey < ActiveRecord::Migration[8.1]
  # "magic_key" was the hidden identifier tying a materialized row back to its
  # built-in. Renamed to "builtin_key" so the whole built-in callout stack reads
  # consistently (BuiltinCallouts / BuiltinCalloutCards / builtin_key).
  OLD_INDEX = "index_registration_ticket_callouts_on_event_id_and_magic_key"
  NEW_INDEX = "index_registration_ticket_callouts_on_event_id_and_builtin_key"

  def up
    rename_column :registration_ticket_callouts, :magic_key, :builtin_key
    rename_index :registration_ticket_callouts, OLD_INDEX, NEW_INDEX if index_name_exists?(:registration_ticket_callouts, OLD_INDEX)
  end

  def down
    rename_index :registration_ticket_callouts, NEW_INDEX, OLD_INDEX if index_name_exists?(:registration_ticket_callouts, NEW_INDEX)
    rename_column :registration_ticket_callouts, :builtin_key, :magic_key
  end
end
