class CreateScholarships < ActiveRecord::Migration[8.1]
  def change
    create_table :scholarships do |t|
      t.integer :amount_cents, null: false, default: 0
      t.boolean :tasks_completed, null: false, default: false
      t.timestamps
    end

    remove_column :event_registrations, :scholarship_recipient, :boolean
    remove_column :event_registrations, :scholarship_tasks_completed, :boolean
  end
end
