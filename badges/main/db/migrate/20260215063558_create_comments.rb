class CreateComments < ActiveRecord::Migration[8.1]
  def change
    create_table :comments do |t|
      t.text :body, null: false
      t.references :commentable, polymorphic: true, null: false
      t.references :created_by, null: true, type: :integer, foreign_key: { to_table: :users }
      t.references :updated_by, null: true, type: :integer, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :comments, [ :commentable_type, :commentable_id, :created_at ]
  end
end
