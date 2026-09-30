class CreateStoriesWorkshops < ActiveRecord::Migration[8.0]
  def up
    create_table :stories_workshops do |t|
      t.references :story, null: false, foreign_key: true
      t.references :workshop, null: true, foreign_key: true, type: :integer
      t.string :external_workshop_title
      t.integer :position
      t.timestamps
    end
    add_index :stories_workshops, [ :story_id, :position ]
    add_index :stories_workshops, [ :story_id, :workshop_id ], unique: true,
              name: "index_stories_workshops_on_story_id_and_workshop_id"
  end

  def down
    drop_table :stories_workshops, if_exists: true
  end
end
