class RenameOrderToPositionOnAnswerOptions < ActiveRecord::Migration[8.1]
  def change
    rename_column :answer_options, :order, :position
  end
end
