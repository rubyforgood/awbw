class CreateFormBuilders < ActiveRecord::Migration
  def change
    create_table :form_builders do |t|
      t.string :name
      t.integer :owner_type
      t.timestamps null: false
    end
  end
end
