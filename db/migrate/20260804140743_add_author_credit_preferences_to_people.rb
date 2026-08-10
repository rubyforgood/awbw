class AddAuthorCreditPreferencesToPeople < ActiveRecord::Migration[8.0]
  def up
    unless column_exists?(:people, :anonymous_contributions)
      add_column :people, :anonymous_contributions, :boolean, default: false, null: false
    end

    # Stamped when an admin resolves this person on the author credit divergences
    # page, so a deliberate divergence stops reappearing on the worklist.
    unless column_exists?(:people, :author_credit_reconciled_at)
      add_column :people, :author_credit_reconciled_at, :datetime
    end
  end

  def down
    remove_column :people, :anonymous_contributions, if_exists: true
    remove_column :people, :author_credit_reconciled_at, if_exists: true
  end
end
