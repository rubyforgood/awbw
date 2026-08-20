class ChangeMissionVisionValuesToText < ActiveRecord::Migration[8.1]
  def up
    change_column :organizations, :mission_vision_values, :text
  end

  def down
    change_column :organizations, :mission_vision_values, :string
  end
end
