class CreateStories < ActiveRecord::Migration[8.1]
  def change
    create_table :stories do |t|
      t.references :story_idea, null: true, index: true, foreign_key: true

      t.integer :windows_type_id, null: false, index: true
      t.foreign_key :windows_types


      t.integer :project_id, null: false, index: true
      t.foreign_key :projects

      t.integer :workshop_id, null: false, index: true
      t.foreign_key :workshops

      t.string :title
      t.text :body
      t.string :youtube_url
      t.boolean :permission_given
      t.boolean :published, null: false, default: false, index: true

      t.timestamps


      t.integer :created_by_id, null: false, index: true
      t.integer :updated_by_id, null: false, index: true
    end

    # Add foreign keys separately
    add_foreign_key :stories, :users, column: :created_by_id
    add_foreign_key :stories, :users, column: :updated_by_id
  end
end
