class CreateWorkshopVariationIdeas < ActiveRecord::Migration[8.0]
  def change
    create_table :workshop_variation_ideas do |t|
      t.string :name, null: false
      t.text :description, size: :long
      t.string :youtube_url
      t.boolean :inactive, default: true
      t.integer :position
      t.references :workshop, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.references :updated_by, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :workshop_variation_ideas, :name
  end
end
