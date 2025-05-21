class CreateReportFormFieldAnswers < ActiveRecord::Migration
  def change
    create_table :report_form_field_answers do |t|
      t.references :report, index: true
      t.references :form_field, index: true
      t.text :answer

      t.timestamps
    end
    add_foreign_key :report_form_field_answers, :reports
    add_foreign_key :report_form_field_answers, :form_fields
  end
end
