class RenameFacilitatorIdToPersonIdInUser < ActiveRecord::Migration[8.1]
  def change
    if column_exists?(:users, :facilitator_id)
      rename_column :users, :facilitator_id, :person_id
    end

    if foreign_key_exists?(:users, :facilitators)
      remove_foreign_key :users, :facilitators
    end

    unless foreign_key_exists?(:users, column: :person_id)
      add_foreign_key :users, :people, column: :person_id
    end
  end
end
