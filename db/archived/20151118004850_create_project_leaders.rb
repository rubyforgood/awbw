class CreateProjectLeaders < ActiveRecord::Migration
  def change
    create_table :project_leaders do |t|
      t.references :agency, index: true
      t.references :user, index: true
      t.integer :position

      t.timestamps null: false
    end
    add_foreign_key :project_leaders, :agencies
    add_foreign_key :project_leaders, :users
  end
end
