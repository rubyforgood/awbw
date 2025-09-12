class CreateWorkshopLogs < ActiveRecord::Migration
  def change
    create_table :workshop_logs do |t|
      t.references :workshop, index: true
      t.references :user, index: true
      t.date :date
      t.integer :rating, default: 0
      t.text :reaction
      t.text :successes
      t.text :challenges
      t.text :suggestions
      t.text :questions
      t.boolean :lead_similar
      t.text :similarities
      t.text :differences
      t.text :comments

      t.timestamps null: false
    end
    add_foreign_key :workshop_logs, :workshops
    add_foreign_key :workshop_logs, :users
  end
end
