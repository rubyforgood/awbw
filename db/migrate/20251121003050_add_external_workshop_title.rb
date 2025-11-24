class AddExternalWorkshopTitle < ActiveRecord::Migration[8.1]
  def change
    add_column :story_ideas, :external_workshop_title, :string
    add_column :stories, :external_workshop_title, :string
  end
end
