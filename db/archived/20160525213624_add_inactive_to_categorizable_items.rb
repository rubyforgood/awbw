class AddInactiveToCategorizableItems < ActiveRecord::Migration[4.2]
  def change
    add_column :categorizable_items, :inactive, :boolean, default: true
  end
end
