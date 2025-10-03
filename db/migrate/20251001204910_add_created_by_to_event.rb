class AddCreatedByToEvent < ActiveRecord::Migration[8.1]
  def change
    add_reference :events, :created_by, foreign_key: { to_table: :users },
                  index: true, null: true, type: :integer
  end
end
