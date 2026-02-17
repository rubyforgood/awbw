class AddStorySpecificAndDisplayTextToCategoryTypes < ActiveRecord::Migration[8.1]
  def change
    add_column :category_types, :story_specific, :boolean, default: false
    add_column :category_types, :display_text, :string
  end
end
