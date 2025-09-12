class CreateNotifications < ActiveRecord::Migration
  def change
    create_table :notifications do |t|
      t.references :report, index: true

      t.timestamps null: false
    end
    add_foreign_key :notifications, :reports
  end
end
