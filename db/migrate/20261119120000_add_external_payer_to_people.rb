class AddExternalPayerToPeople < ActiveRecord::Migration[8.1]
  def change
    add_column :people, :external_payer, :boolean
    add_index :people, :external_payer, unique: true
  end
end
