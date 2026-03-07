class AddWorkshopLogIdToReportFormFieldAnswers < ActiveRecord::Migration[8.1]
  def change
    add_column :report_form_field_answers, :workshop_log_id, :integer
    add_index :report_form_field_answers, :workshop_log_id
    add_foreign_key :report_form_field_answers, :workshop_logs
    change_column_null :report_form_field_answers, :report_id, true
  end
end
