class AddPreTitleToEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :events, :pre_title, :string
  end
end
