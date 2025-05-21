class CreateResources < ActiveRecord::Migration
  def change
    create_table :resources do |t|
      t.string :title
      t.string :author
      t.references :user, index: true
      t.text :text
      t.boolean :featured, default: false

      t.timestamps null: false
    end
    add_foreign_key :resources, :users
  end
end
