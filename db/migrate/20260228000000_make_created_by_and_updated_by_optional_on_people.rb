class MakeCreatedByAndUpdatedByOptionalOnPeople < ActiveRecord::Migration[8.1]
  def change
    change_column_null :people, :created_by_id, true
    change_column_null :people, :updated_by_id, true
  end
end
