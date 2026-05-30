class ChangePaymentsPayerToPersonOrganization < ActiveRecord::Migration[8.1]
  def change
    remove_index :payments, name: "index_payments_on_payer"
    remove_index :payments, name: "index_payments_on_payer_type_and_payer_id"

    remove_column :payments, :payer_id

    add_reference :payments, :person, foreign_key: true
    add_reference :payments, :organization, type: :integer, foreign_key: true
  end
end
