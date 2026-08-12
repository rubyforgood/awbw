class AddPrNumberToFeatures < ActiveRecord::Migration[8.1]
  def change
    add_column :features, :pr_number, :integer
  end
end
