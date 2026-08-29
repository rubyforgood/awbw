class AddAffiliationsReconciledAtToEvents < ActiveRecord::Migration[8.1]
  def up
    unless column_exists?(:events, :affiliations_reconciled_at)
      add_column :events, :affiliations_reconciled_at, :datetime, null: true
    end
  end

  def down
    remove_column :events, :affiliations_reconciled_at, if_exists: true
  end
end
