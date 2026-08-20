class AddPronunciationToPeople < ActiveRecord::Migration[8.1]
  def up
    add_column :people, :pronunciation, :string unless column_exists?(:people, :pronunciation)
  end

  def down
    remove_column :people, :pronunciation, if_exists: true
  end
end
