class CreateStoryIdeas < ActiveRecord::Migration[8.1]
  def change
    create_table :story_ideas do |t|
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
      t.string :publish_preferences

      t.timestamps


      t.integer :created_by_id, null: false, index: true
      t.integer :updated_by_id, null: false, index: true
    end

    # Add foreign keys separately
    add_foreign_key :story_ideas, :users, column: :created_by_id
    add_foreign_key :story_ideas, :users, column: :updated_by_id
  end
end
