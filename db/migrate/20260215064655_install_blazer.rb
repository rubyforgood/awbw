class InstallBlazer < ActiveRecord::Migration[8.1]
  def change
    create_table :blazer_queries do |t|
      t.references :creator, foreign_key: { to_table: :users }
      t.string :name
      t.text :description
      t.text :statement
      t.string :data_source
      t.string :status
      t.timestamps null: false
    end

    create_table :blazer_audits do |t|
      t.references :user, foreign_key: true
      t.references :query, foreign_key: { to_table: :blazer_queries }
      t.text :statement
      t.string :data_source
      t.datetime :created_at
    end

    create_table :blazer_dashboards do |t|
      t.references :creator, foreign_key: { to_table: :users }
      t.string :name
      t.timestamps null: false
    end

    create_table :blazer_dashboard_queries do |t|
      t.references :dashboard, foreign_key: { to_table: :blazer_dashboards }
      t.references :query, foreign_key: { to_table: :blazer_queries }
      t.integer :position
      t.timestamps null: false
    end

    create_table :blazer_checks do |t|
      t.references :creator, foreign_key: { to_table: :users }
      t.references :query, foreign_key: { to_table: :blazer_queries }
      t.string :state
      t.string :schedule
      t.text :emails
      t.text :slack_channels
      t.string :check_type
      t.text :message
      t.datetime :last_run_at
      t.timestamps null: false
    end
  end
end
