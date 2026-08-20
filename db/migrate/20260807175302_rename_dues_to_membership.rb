class RenameDuesToMembership < ActiveRecord::Migration[8.1]
  def change
    rename_table :dues_subscriptions, :memberships
    rename_table :dues_registrations, :membership_invoices
    rename_column :membership_invoices, :dues_subscription_id, :membership_id
  end
end
