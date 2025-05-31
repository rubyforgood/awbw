class CreateProjectObligations < ActiveRecord::Migration[4.2]
  def change
    create_table :project_obligations do |t|
      t.string :name

      t.timestamps null: false
    end
  end
end
