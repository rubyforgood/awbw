class AddCeAdministratorToSettings < ActiveRecord::Migration[8.1]
  def up
    add_reference :settings, :ce_administrator unless column_exists?(:settings, :ce_administrator_id)
    unless foreign_key_exists?(:settings, column: :ce_administrator_id)
      add_foreign_key :settings, :people, column: :ce_administrator_id, on_delete: :nullify
    end
  end

  def down
    remove_foreign_key :settings, column: :ce_administrator_id if foreign_key_exists?(:settings, column: :ce_administrator_id)
    remove_reference :settings, :ce_administrator if column_exists?(:settings, :ce_administrator_id)
  end
end
