class ChangeInvoicesRemoveBillToNameAddAttentionPersonId < ActiveRecord::Migration[8.1]
  def change
    remove_column :invoices, :bill_to_name, :string
    remove_column :invoices, :attention, :string
    add_reference :invoices, :attention_person, foreign_key: { to_table: :people }
  end
end
