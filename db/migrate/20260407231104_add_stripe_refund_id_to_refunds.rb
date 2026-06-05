class AddStripeRefundIdToRefunds < ActiveRecord::Migration[8.1]
  def change
    add_column :refunds, :stripe_refund_id, :string
    add_index :refunds, :stripe_refund_id
  end
end
