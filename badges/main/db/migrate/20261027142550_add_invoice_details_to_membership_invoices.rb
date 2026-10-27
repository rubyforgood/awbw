class AddInvoiceDetailsToMembershipInvoices < ActiveRecord::Migration[8.1]
  def up
    add_column :membership_invoices, :invoicee_type, :string unless column_exists?(:membership_invoices, :invoicee_type)
    add_column :membership_invoices, :invoicee_id, :bigint unless column_exists?(:membership_invoices, :invoicee_id)
    add_column :membership_invoices, :bill_to_address_id, :bigint unless column_exists?(:membership_invoices, :bill_to_address_id)
    add_column :membership_invoices, :hide_invoicee, :boolean unless column_exists?(:membership_invoices, :hide_invoicee)
    add_column :membership_invoices, :hide_address, :boolean unless column_exists?(:membership_invoices, :hide_address)
    add_column :membership_invoices, :bill_to_additional_info, :text unless column_exists?(:membership_invoices, :bill_to_additional_info)
    add_column :membership_invoices, :attention_person_id, :bigint unless column_exists?(:membership_invoices, :attention_person_id)
  end

  def down
    remove_column :membership_invoices, :invoicee_type, if_exists: true
    remove_column :membership_invoices, :invoicee_id, if_exists: true
    remove_column :membership_invoices, :bill_to_address_id, if_exists: true
    remove_column :membership_invoices, :hide_invoicee, if_exists: true
    remove_column :membership_invoices, :hide_address, if_exists: true
    remove_column :membership_invoices, :bill_to_additional_info, if_exists: true
    remove_column :membership_invoices, :attention_person_id, if_exists: true
  end
end
