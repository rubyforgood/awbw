class AddCheckoutSessionIdToMembershipInvoices < ActiveRecord::Migration[8.1]
  def change
    add_column :membership_invoices, :checkout_session_id, :string
  end
end
