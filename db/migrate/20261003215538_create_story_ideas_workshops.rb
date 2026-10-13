class CreateStoryIdeasWorkshops < ActiveRecord::Migration[8.0]
  def up
    create_table :story_ideas_workshops do |t|
      t.references :story_idea, null: false, foreign_key: true
      t.references :workshop, null: true, foreign_key: true, type: :integer
      t.string :external_workshop_title
      t.integer :position
      t.timestamps
    end
    add_index :story_ideas_workshops, [ :story_idea_id, :position ]
    # A workshop may repeat within an idea under a different free-text title, so
    # the link is the triple. MySQL exempts NULLs, which StoryIdeaWorkshop covers.
    add_index :story_ideas_workshops, [ :story_idea_id, :workshop_id, :external_workshop_title ], unique: true,
              name: "index_story_ideas_workshops_on_idea_workshop_and_title"
  end

  def down
    drop_table :story_ideas_workshops, if_exists: true
  end
end
