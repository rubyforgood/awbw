class CreateFormFieldAnswerOptions < ActiveRecord::Migration
  def change
    create_table :form_field_answer_options do |t|
      t.references :form_field, index: true
      t.references :answer_option, index: true

      t.timestamps null: false
    end
    add_foreign_key :form_field_answer_options, :form_fields
    add_foreign_key :form_field_answer_options, :answer_options
  end
end
