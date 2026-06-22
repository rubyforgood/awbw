class AddBackfilledToFormAnswers < ActiveRecord::Migration[8.1]
  def up
    add_column :form_answers, :backfilled, :boolean, default: false, null: false
  end

  def down
    remove_column :form_answers, :backfilled, if_exists: true
  end
end
