class AddFulltextSearchTitleToWorkshops < ActiveRecord::Migration[4.2]
  def change
    add_index :workshops, [:title], name: 'workshop_fullsearch_title', type: :fulltext
  end
end
