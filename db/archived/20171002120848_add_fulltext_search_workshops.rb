class AddFulltextSearchWorkshops < ActiveRecord::Migration[4.2]
  def change
    add_index :workshops, [:title, :objective, :materials, :introduction, :demonstration, :opening_circle, :warm_up, :creation, :closing, :notes, :tips, :misc1, :misc2], name: 'workshop_fullsearch', type: :fulltext
  end
end
