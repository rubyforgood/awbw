class CreateCommunityNews < ActiveRecord::Migration[8.1]
  def change
    create_table :community_news do |t|
      t.integer :project_id, null: true, index: true
      t.integer :windows_type_id, null: true, index: true

      t.string :title
      t.text :body
      t.boolean :published
      t.boolean :featured
      t.string :reference_url
      t.string :youtube_url

      t.timestamps

      t.integer :author_id, null: false, index: true
      t.integer :created_by_id, null: false, index: true
      t.integer :updated_by_id, null: false, index: true
    end

    add_foreign_key :community_news, :projects
    add_foreign_key :community_news, :windows_types
    add_foreign_key :community_news, :users, column: :author_id
    add_foreign_key :community_news, :users, column: :created_by_id
    add_foreign_key :community_news, :users, column: :updated_by_id
  end
end
