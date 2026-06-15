class AddEventToFormSubmissions < ActiveRecord::Migration[8.0]
  def up
    add_reference :form_submissions, :event, null: true, index: true, foreign_key: true
  end

  def down
    remove_foreign_key :form_submissions, :events if foreign_key_exists?(:form_submissions, :events)
    remove_reference :form_submissions, :event, index: true if column_exists?(:form_submissions, :event_id)
  end
end
