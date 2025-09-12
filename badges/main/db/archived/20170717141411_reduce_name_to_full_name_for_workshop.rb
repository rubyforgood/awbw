class ReduceNameToFullNameForWorkshop < ActiveRecord::Migration
  def change
    Workshop.find_each do |w|
      w.update(author_first_name: "#{w.author_first_name} #{w.author_last_name}")
    end

    rename_column :workshops, :author_first_name, :full_name
    remove_column :workshops, :author_last_name
  end
end
