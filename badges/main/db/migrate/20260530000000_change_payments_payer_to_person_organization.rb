class ChangePaymentsPayerToPersonOrganization < ActiveRecord::Migration[8.1]
  def up
    remove_index :payments, name: "index_payments_on_payer", if_exists: true
    remove_index :payments, name: "index_payments_on_payer_type_and_payer_id", if_exists: true

    remove_column :payments, :payer_id, if_exists: true

    unless column_exists?(:payments, :person_id)
      add_column :payments, :person_id, :bigint
    end
    add_index :payments, :person_id, if_not_exists: true
    add_foreign_key :payments, :people, column: :person_id unless foreign_key_exists?(:payments, :people, column: :person_id)
    unless column_exists?(:payments, :organization_id)
      add_column :payments, :organization_id, :integer
    end
    add_index :payments, :organization_id, if_not_exists: true
    add_foreign_key :payments, :organizations, column: :organization_id unless foreign_key_exists?(:payments, :organizations, column: :organization_id)
  end

  def down
    remove_reference :payments, :organization, foreign_key: true, if_exists: true
    remove_reference :payments, :person, foreign_key: true, if_exists: true

    add_column :payments, :payer_id, :bigint unless column_exists?(:payments, :payer_id)
    add_index :payments, [ :payer_type, :payer_id ], name: "index_payments_on_payer", if_not_exists: true
    add_index :payments, [ :payer_type, :payer_id ], name: "index_payments_on_payer_type_and_payer_id", if_not_exists: true
  end
end
