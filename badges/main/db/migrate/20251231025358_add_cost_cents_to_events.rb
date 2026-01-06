class AddCostCentsToEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :events, :cost_cents, :integer, null: true
  end
end
