class RemovePublishedFromPeople < ActiveRecord::Migration[8.1]
  def change
    remove_column :people, :published, :boolean
  end
end
