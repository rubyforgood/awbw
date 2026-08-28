class AddCePaymentAccessGatedToRegistrationTicketCallouts < ActiveRecord::Migration[8.1]
  def up
    return if column_exists?(:registration_ticket_callouts, :ce_payment_access_gated)

    add_column :registration_ticket_callouts, :ce_payment_access_gated, :boolean, null: false, default: false
  end

  def down
    remove_column :registration_ticket_callouts, :ce_payment_access_gated, if_exists: true
  end
end
