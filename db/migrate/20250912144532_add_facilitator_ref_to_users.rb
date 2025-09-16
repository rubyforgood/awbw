class AddFacilitatorRefToUsers < ActiveRecord::Migration[6.1]
  def change
    add_reference :users, :facilitator, foreign_key: true, null: true
  end
end
