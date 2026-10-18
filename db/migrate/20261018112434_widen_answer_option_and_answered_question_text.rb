class WidenAnswerOptionAndAnsweredQuestionText < ActiveRecord::Migration[8.1]
  def up
    change_column :answer_options, :name, :string, limit: 2000
    change_column :form_answers, :question_name_when_answered, :text
  end

  def down
    change_column :form_answers, :question_name_when_answered, :string
    change_column :answer_options, :name, :string
  end
end
