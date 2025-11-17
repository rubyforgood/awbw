class CreateFooters < ActiveRecord::Migration
  def change
    create_table :footers do |t|
      t.string :phone
      t.string :children_program
      t.string :adult_program
      t.string :general_questions

      t.timestamps null: false
    end
  end
end
