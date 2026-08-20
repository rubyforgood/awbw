class AddAuthorCreditPreferencesToPeople < ActiveRecord::Migration[8.0]
  def up
    unless column_exists?(:people, :author_credit_reconciled_at)
      add_column :people, :author_credit_reconciled_at, :datetime
    end
  end

  def down
    remove_column :people, :author_credit_reconciled_at, if_exists: true
  end
end
