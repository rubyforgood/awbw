class MakeStoryIdeasOrganizationOptional < ActiveRecord::Migration[8.1]
  def up
    change_column_null :story_ideas, :organization_id, true
  end

  def down
    change_column_null :story_ideas, :organization_id, false
  end
end
