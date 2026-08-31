class CreateRegistrationTicketCalloutForms < ActiveRecord::Migration[8.1]
  # A callout links many forms now (each with its own drip gate), replacing the
  # single form_id column. Existing single-form callouts move to one join row.
  def up
    unless table_exists?(:registration_ticket_callout_forms)
      create_table :registration_ticket_callout_forms do |t|
        t.references :registration_ticket_callout, null: false, foreign_key: { on_delete: :cascade }
        t.integer :form_id, null: false
        t.datetime :display_from
        t.integer :position, null: false
        t.integer :created_by_id
        t.integer :updated_by_id
        t.timestamps
      end
      add_index :registration_ticket_callout_forms, :form_id
      add_index :registration_ticket_callout_forms, :created_by_id
      add_index :registration_ticket_callout_forms, :updated_by_id
      add_foreign_key :registration_ticket_callout_forms, :forms, column: :form_id
    end

    remove_reference :registration_ticket_callouts, :form, foreign_key: true if column_exists?(:registration_ticket_callouts, :form_id)
  end

  def down
    unless column_exists?(:registration_ticket_callouts, :form_id)
      add_reference :registration_ticket_callouts, :form, type: :integer, foreign_key: true, null: true
    end

    drop_table :registration_ticket_callout_forms, if_exists: true
  end
end
