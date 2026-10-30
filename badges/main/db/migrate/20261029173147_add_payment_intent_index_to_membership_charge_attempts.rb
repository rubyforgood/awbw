class AddPaymentIntentIndexToMembershipChargeAttempts < ActiveRecord::Migration[8.1]
  def change
    add_index :membership_charge_attempts, :payment_intent_id
  end
end
