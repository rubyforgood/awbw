class AddFilemakerCodeToProjectLeaders < ActiveRecord::Migration[4.2]
  def change
    add_column :project_leaders, :filemaker_code, :string
  end
end
