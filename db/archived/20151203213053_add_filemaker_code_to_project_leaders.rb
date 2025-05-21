class AddFilemakerCodeToProjectLeaders < ActiveRecord::Migration
  def change
    add_column :project_leaders, :filemaker_code, :string
  end
end
