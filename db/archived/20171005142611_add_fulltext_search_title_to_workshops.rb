class AddFulltextSearchTitleToWorkshops < ActiveRecord::Migration
  def change
    add_index :workshops, [:title], name: 'workshop_fullsearch_title', type: :fulltext
  end
end
