class AddUniqueIndexOnStripeRefundIdToRefunds < ActiveRecord::Migration[8.1]
  def change
    remove_index :refunds, :stripe_refund_id
    add_index :refunds, :stripe_refund_id, unique: true
  end
end
