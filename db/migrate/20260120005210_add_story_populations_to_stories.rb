class AddStoryPopulationsToStories < ActiveRecord::Migration[8.1]
  def change
    add_column :stories, :story_populations, :json
  end
end
