class DropFormLevelHideAnsweredFlags < ActiveRecord::Migration[8.1]
  def up
    remove_column :forms, :hide_answered_form_questions, if_exists: true
    remove_column :forms, :hide_answered_person_questions, if_exists: true
  end

  def down
    add_column :forms, :hide_answered_form_questions, :boolean, default: false, null: false unless column_exists?(:forms, :hide_answered_form_questions)
    add_column :forms, :hide_answered_person_questions, :boolean, default: false, null: false unless column_exists?(:forms, :hide_answered_person_questions)
  end
end
