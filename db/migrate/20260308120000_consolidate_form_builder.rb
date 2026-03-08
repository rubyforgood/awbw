class ConsolidateFormBuilder < ActiveRecord::Migration[8.0]
  def change
    # Rename tables
    rename_table :person_forms, :form_submissions
    rename_table :person_form_form_fields, :form_answers

    # Rename foreign key column to match new table name
    rename_column :form_answers, :person_form_id, :form_submission_id

    # Add question_text snapshot to form_answers (preserves question at submission time)
    add_column :form_answers, :question_text, :string

    # Allow form_field deletion without orphaning answers
    change_column_null :form_answers, :form_field_id, true

    # Add sections and conditional visibility to forms
    add_column :forms, :sections, :json
    add_column :forms, :hide_answered_person_questions, :boolean, default: false, null: false
    add_column :forms, :hide_answered_form_questions, :boolean, default: false, null: false

    # Note: keeping form_fields.status column for now — still used by
    # workshop logs, reports, and resources. Event registration code
    # will stop filtering by status in this PR.
  end
end
