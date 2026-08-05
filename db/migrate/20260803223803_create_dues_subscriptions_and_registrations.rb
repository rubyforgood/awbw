class CreateDuesSubscriptionsAndRegistrations < ActiveRecord::Migration[8.1]
  def change
    create_table :dues_subscriptions do |t|
      t.references :person, null: false, foreign_key: true
      t.integer :cost_cents
      t.datetime :cancelled_at
      t.timestamps
    end

    create_table :dues_registrations do |t|
      t.references :dues_subscription, null: false, foreign_key: true
      t.date :start_date, null: false
      t.date :end_date, null: false
      t.integer :cost_cents, null: false, default: 0
      t.timestamps
    end

    add_index :dues_registrations, [ :start_date, :end_date ]
  end
end
