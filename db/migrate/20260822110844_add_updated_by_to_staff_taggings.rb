class AddUpdatedByToStaffTaggings < ActiveRecord::Migration[7.2]
  def change
    add_column :staff_taggings, :updated_by_id, :bigint
    add_index :staff_taggings, :updated_by_id
  end
end
