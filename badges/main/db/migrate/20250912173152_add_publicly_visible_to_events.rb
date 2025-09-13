class AddPubliclyVisibleToEvents < ActiveRecord::Migration[6.1]
  def change
    add_column :events, :publicly_visible, :boolean, default: false, null: false
  end
end
