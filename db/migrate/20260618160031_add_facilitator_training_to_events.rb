class AddFacilitatorTrainingToEvents < ActiveRecord::Migration[8.1]
  def up
    add_column :events, :facilitator_training, :boolean, default: false, null: false
    add_index :events, :facilitator_training
  end

  def down
    remove_index :events, :facilitator_training, if_exists: true
    remove_column :events, :facilitator_training, if_exists: true
  end
end
