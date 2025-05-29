class CreateAnswerOptions < ActiveRecord::Migration[4.2]
  def change
    create_table :answer_options do |t|
      t.string :name
      t.integer :order
      t.timestamps null: false
    end
  end
end
