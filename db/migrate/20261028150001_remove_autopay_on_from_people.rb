class RemoveAutopayOnFromPeople < ActiveRecord::Migration[8.1]
  def change
    remove_column :people, :autopay_on, :boolean
  end
end
