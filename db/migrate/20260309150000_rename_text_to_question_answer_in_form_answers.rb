class RenameTextToQuestionAnswerInFormAnswers < ActiveRecord::Migration[8.0]
  def change
    rename_column :form_answers, :text, :question_answer
  end
end
