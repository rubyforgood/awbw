class RenameGroupPaymentEnabledToBulkPaymentEnabled < ActiveRecord::Migration[8.1]
  def change
    rename_column :events, :group_payment_enabled, :bulk_payment_enabled
  end
end
