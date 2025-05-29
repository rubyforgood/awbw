class AddQuestionToFormFields < ActiveRecord::Migration[4.2]
  def change
    add_column :form_fields, :question, :string
  end
end
