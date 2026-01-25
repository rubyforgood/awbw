class ChangePositionDefaultToNil < ActiveRecord::Migration[8.1]
  def change
    change_column_default :categories, :position, from: 0, to: nil
  end
end
