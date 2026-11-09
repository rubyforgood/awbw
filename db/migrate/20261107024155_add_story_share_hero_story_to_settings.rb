class AddStoryShareHeroStoryToSettings < ActiveRecord::Migration[8.1]
  def up
    add_reference :settings, :story_share_hero_story unless column_exists?(:settings, :story_share_hero_story_id)
    unless foreign_key_exists?(:settings, column: :story_share_hero_story_id)
      add_foreign_key :settings, :stories, column: :story_share_hero_story_id, on_delete: :nullify
    end
  end

  def down
    remove_foreign_key :settings, column: :story_share_hero_story_id if foreign_key_exists?(:settings, column: :story_share_hero_story_id)
    remove_reference :settings, :story_share_hero_story if column_exists?(:settings, :story_share_hero_story_id)
  end
end
