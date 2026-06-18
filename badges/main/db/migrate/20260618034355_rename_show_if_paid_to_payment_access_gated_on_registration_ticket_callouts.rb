class RenameShowIfPaidToPaymentAccessGatedOnRegistrationTicketCallouts < ActiveRecord::Migration[7.2]
  def up
    return unless column_exists?(:registration_ticket_callouts, :show_if_paid)

    rename_column :registration_ticket_callouts, :show_if_paid, :payment_access_gated
  end

  def down
    return unless column_exists?(:registration_ticket_callouts, :payment_access_gated)

    rename_column :registration_ticket_callouts, :payment_access_gated, :show_if_paid
  end
end
