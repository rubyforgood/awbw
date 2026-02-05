class AddPubliclyVisibleToModels < ActiveRecord::Migration[8.1]
  def change
    add_column :faqs, :publicly_visible, :boolean, default: false, null: false
    add_column :tutorials, :publicly_visible, :boolean, default: false, null: false
  end
end
