class AddAnswerOptionIdToReportFormFieldAnswers < ActiveRecord::Migration[4.2]
  def change
    add_reference :report_form_field_answers, :answer_option, index: true
    add_foreign_key :report_form_field_answers, :answer_options
  end
end
