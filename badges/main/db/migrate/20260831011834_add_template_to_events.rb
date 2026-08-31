class AddTemplateToEvents < ActiveRecord::Migration[8.1]
  def up
    add_column :events, :template, :string, default: "none", null: false unless column_exists?(:events, :template)
  end

  def down
    remove_column :events, :template, if_exists: true
  end
end
