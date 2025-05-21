class AddQuestionToFormFields < ActiveRecord::Migration
  def change
    add_column :form_fields, :question, :string
  end
end
