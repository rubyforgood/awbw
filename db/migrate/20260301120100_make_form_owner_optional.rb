class MakeFormOwnerOptional < ActiveRecord::Migration[8.1]
  def change
    change_column_null :forms, :owner_id, true
    change_column_null :forms, :owner_type, true
  end
end
