class AddDisplayRichTextToResources < ActiveRecord::Migration[8.1]
  def change
    add_column :resources, :display_rich_text, :boolean
  end
end
