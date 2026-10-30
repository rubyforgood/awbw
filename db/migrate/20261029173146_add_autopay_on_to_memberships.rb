class AddAutopayOnToMemberships < ActiveRecord::Migration[8.1]
  def change
    add_column :memberships, :autopay_on, :boolean, default: false, null: false
  end
end
