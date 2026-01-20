class AddStoryPopulationsToStoryIdeas < ActiveRecord::Migration[8.1]
  def change
    add_column :story_ideas, :story_populations, :json
  end
end
