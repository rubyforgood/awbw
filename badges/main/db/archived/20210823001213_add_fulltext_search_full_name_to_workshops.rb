class AddFulltextSearchFullNameToWorkshops < ActiveRecord::Migration
  def change
    remove_index :workshops, name: 'workshop_fullsearch'
    add_index :workshops, [:title, :full_name, :objective, :materials, :introduction, :demonstration, :opening_circle, :warm_up, :creation, :closing, :notes, :tips, :misc1, :misc2], name: 'workshop_fullsearch', type: :fulltext
  end
end
