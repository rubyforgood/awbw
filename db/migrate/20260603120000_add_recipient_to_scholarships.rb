class AddRecipientToScholarships < ActiveRecord::Migration[8.1]
  def change
    add_reference :scholarships, :recipient, null: false, foreign_key: { to_table: :people }
  end
end
