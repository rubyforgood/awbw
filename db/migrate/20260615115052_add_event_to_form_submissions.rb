class AddEventToFormSubmissions < ActiveRecord::Migration[8.0]
  def up
    add_reference :form_submissions, :event, null: true, index: true
    add_foreign_key :form_submissions, :events unless foreign_key_exists?(:form_submissions, :events)

    # Backfill the event for existing submissions by matching the join role.
    # Registration submissions carry no role, so they resolve through the
    # "registration" event_form.
    execute(<<~SQL.squish)
      UPDATE form_submissions fs
      JOIN event_forms ef
        ON ef.form_id = fs.form_id
        AND ef.role = COALESCE(fs.role, 'registration')
      SET fs.event_id = ef.event_id
      WHERE fs.event_id IS NULL
    SQL
  end

  def down
    remove_foreign_key :form_submissions, :events if foreign_key_exists?(:form_submissions, :events)
    remove_reference :form_submissions, :event, index: true if column_exists?(:form_submissions, :event_id)
  end
end
