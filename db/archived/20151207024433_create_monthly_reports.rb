class CreateMonthlyReports < ActiveRecord::Migration
  def change
    create_table :monthly_reports do |t|
      t.string :month
      t.references :project, index: true
      t.references :project_user, index: true
      t.string :name
      t.string :position
      t.boolean :mail_evaluations
      t.string :num_ongoing_participants
      t.string :num_new_participants
      t.text :most_effective
      t.text :most_challenging
      t.text :goals_reached
      t.text :goals
      t.text :comments
      t.boolean :call_requested
      t.string :best_call_time
      t.string :phone

      t.timestamps null: false
    end
    add_foreign_key :monthly_reports, :projects
    add_foreign_key :monthly_reports, :project_users
  end
end
