class AddOrganizationToMembershipInvoices < ActiveRecord::Migration[8.1]
  def change
    add_reference :membership_invoices, :organization, type: :integer, null: true, foreign_key: true
  end
end
