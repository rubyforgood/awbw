class AddWorkshopLogIdToReportFormFieldAnswers < ActiveRecord::Migration[8.1]
  def up
    add_column :report_form_field_answers, :workshop_log_id, :integer
    add_index :report_form_field_answers, :workshop_log_id
    add_foreign_key :report_form_field_answers, :workshop_logs
    change_column_null :report_form_field_answers, :report_id, true
  end

  def down
    remove_foreign_key :report_form_field_answers, :workshop_logs, if_exists: true
    remove_index :report_form_field_answers, :workshop_log_id, if_exists: true
    remove_column :report_form_field_answers, :workshop_log_id if column_exists?(:report_form_field_answers, :workshop_log_id)
    change_column_null :report_form_field_answers, :report_id, false
  end
end
