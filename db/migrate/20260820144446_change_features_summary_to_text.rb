class ChangeFeaturesSummaryToText < ActiveRecord::Migration[8.1]
  def up
    change_column :features, :summary, :text, null: false
  end

  def down
    change_column :features, :summary, :string, null: false
  end
end
