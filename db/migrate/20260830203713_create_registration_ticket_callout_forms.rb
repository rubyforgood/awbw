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

    if column_exists?(:registration_ticket_callouts, :form_id)
      execute <<~SQL.squish
        INSERT INTO registration_ticket_callout_forms
          (registration_ticket_callout_id, form_id, display_from, position, created_at, updated_at)
        SELECT id, form_id, display_from, 1, NOW(), NOW()
        FROM registration_ticket_callouts
        WHERE form_id IS NOT NULL
      SQL
      remove_reference :registration_ticket_callouts, :form, foreign_key: true
    end
  end

  def down
    unless column_exists?(:registration_ticket_callouts, :form_id)
      add_reference :registration_ticket_callouts, :form, type: :integer, foreign_key: true, null: true
    end

    if table_exists?(:registration_ticket_callout_forms)
      execute <<~SQL.squish
        UPDATE registration_ticket_callouts c
        INNER JOIN registration_ticket_callout_forms cf
          ON cf.registration_ticket_callout_id = c.id AND cf.position = 1
        SET c.form_id = cf.form_id
      SQL
      drop_table :registration_ticket_callout_forms
    end
  end
end
