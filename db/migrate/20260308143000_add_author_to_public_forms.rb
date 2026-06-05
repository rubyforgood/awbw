class AddAuthorToPublicForms < ActiveRecord::Migration[8.1]
  def change
    add_reference :stories, :author, foreign_key: { to_table: :users }, null: true
    add_reference :events, :author, foreign_key: { to_table: :users }, null: true
    add_reference :resources, :author, foreign_key: { to_table: :users }, null: true
    add_reference :tutorials, :author, foreign_key: { to_table: :users }, null: true
    add_reference :tutorials, :created_by, foreign_key: { to_table: :users }, null: true
  end
end
