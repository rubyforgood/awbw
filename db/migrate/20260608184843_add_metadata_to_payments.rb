class AddMetadataToPayments < ActiveRecord::Migration[8.1]
  def change
    unless column_exists?(:payments, :metadata)
      add_column :payments, :metadata, :json
    end
  end
end
