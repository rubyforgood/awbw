class CreateComments < ActiveRecord::Migration[8.1]
  def change
    create_table :comments do |t|
      t.text :body, null: false
      t.references :commentable, polymorphic: true, null: false

      t.timestamps
    end

    add_index :comments, [ :commentable_type, :commentable_id, :created_at ]
  end
end
