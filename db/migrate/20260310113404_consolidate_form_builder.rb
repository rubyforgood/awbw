class ConsolidateFormBuilder < ActiveRecord::Migration[8.0]
  def change
    # Rename tables
    rename_table :person_forms, :form_submissions
    rename_table :person_form_form_fields, :form_answers

    # Rename foreign key column to match new table name
    rename_column :form_answers, :person_form_id, :form_submission_id

    # Snapshot of question name at submission time
    add_column :form_answers, :question_name_when_answered, :string

    # Allow form_field deletion without orphaning answers
    change_column_null :form_answers, :form_field_id, true

    # Add sections and conditional visibility to forms
    add_column :forms, :sections, :json
    add_column :forms, :hide_answered_person_questions, :boolean, default: false, null: false
    add_column :forms, :hide_answered_form_questions, :boolean, default: false, null: false

    # Per-field conditional visibility
    add_column :form_fields, :visibility, :integer, default: 0, null: false
    add_column :form_fields, :one_time, :boolean, default: false, null: false

    # Rename text to submitted_answer for clarity
    rename_column :form_answers, :text, :submitted_answer

    # Rename is_required to required
    rename_column :form_fields, :is_required, :required

    # Batch column renames for clarity
    rename_column :form_fields, :question, :name
    rename_column :form_fields, :field_group, :section
    # answer_type keeps its original name
    rename_column :form_fields, :instructional_hint, :hint_text
    rename_column :form_fields, :answer_datatype, :input_type
    rename_column :form_fields, :field_key, :field_identifier

    # Enforce NOT NULL on required foreign keys
    change_column_null :form_submissions, :form_id, false
    change_column_null :form_submissions, :person_id, false
    change_column_null :form_answers, :form_submission_id, false
  end
end
