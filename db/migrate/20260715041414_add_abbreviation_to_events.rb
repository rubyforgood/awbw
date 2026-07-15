class AddAbbreviationToEvents < ActiveRecord::Migration[8.1]
  def up
    add_column :events, :abbreviation, :string unless column_exists?(:events, :abbreviation)
  end

  def down
    remove_column :events, :abbreviation, if_exists: true
  end
end
