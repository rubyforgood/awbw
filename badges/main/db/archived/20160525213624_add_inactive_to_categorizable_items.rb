class AddInactiveToCategorizableItems < ActiveRecord::Migration
  def change
    add_column :categorizable_items, :inactive, :boolean, default: true
  end
end
