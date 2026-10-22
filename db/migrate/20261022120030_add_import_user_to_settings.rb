class AddImportUserToSettings < ActiveRecord::Migration[8.1]
  def up
    add_reference :settings, :import_user, type: :integer unless column_exists?(:settings, :import_user_id)
    unless foreign_key_exists?(:settings, column: :import_user_id)
      add_foreign_key :settings, :users, column: :import_user_id, on_delete: :nullify
    end
  end

  def down
    remove_foreign_key :settings, column: :import_user_id if foreign_key_exists?(:settings, column: :import_user_id)
    remove_reference :settings, :import_user if column_exists?(:settings, :import_user_id)
  end
end
