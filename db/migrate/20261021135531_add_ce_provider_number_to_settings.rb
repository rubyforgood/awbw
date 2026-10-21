class AddCeProviderNumberToSettings < ActiveRecord::Migration[8.1]
  def up
    add_column :settings, :ce_provider_number, :string unless column_exists?(:settings, :ce_provider_number)
  end

  def down
    remove_column :settings, :ce_provider_number, if_exists: true
  end
end
