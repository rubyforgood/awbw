class RenameFacilitatorsToPeople < ActiveRecord::Migration[8.1]
  def change
    rename_table :facilitators, :people
  end
end
