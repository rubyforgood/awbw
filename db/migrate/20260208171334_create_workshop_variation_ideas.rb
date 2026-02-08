class CreateWorkshopVariationIdeas < ActiveRecord::Migration[8.0]
  def change
    create_table :workshop_variation_ideas do |t|
      t.string :name, null: false
      t.text :body, size: :long
      t.string :youtube_url
      t.boolean "permission_given"
      t.string "publish_preferences"
      t.references :organization, null: false, foreign_key: true, type: :integer
      t.references :windows_type, null: false, foreign_key: true, type: :integer
      t.references :workshop, null: false, foreign_key: true, type: :integer
      t.references :created_by, null: false, foreign_key: { to_table: :users }, type: :integer
      t.references :updated_by, null: false, foreign_key: { to_table: :users }, type: :integer

      t.timestamps
    end

    add_index :workshop_variation_ideas, :name
    add_index :workshop_variation_ideas, :body, type: :fulltext
  end
end
