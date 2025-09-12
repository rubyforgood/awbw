class CreateUserForms < ActiveRecord::Migration
  def change
    create_table :user_forms do |t|
      t.references :user, index: true
      t.references :form, index: true

      t.timestamps null: false
    end
    add_foreign_key :user_forms, :users
    add_foreign_key :user_forms, :forms
  end
end
