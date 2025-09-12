class CreateProjectObligations < ActiveRecord::Migration
  def change
    create_table :project_obligations do |t|
      t.string :name

      t.timestamps null: false
    end
  end
end
