class RemoveAttentionStringFromInvoices < ActiveRecord::Migration[8.1]
  def change
    remove_column :invoices, :attention, :string
  end
end
