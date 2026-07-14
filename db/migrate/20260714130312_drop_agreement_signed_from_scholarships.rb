class DropAgreementSignedFromScholarships < ActiveRecord::Migration[8.1]
  # agreement_signed is redundant with agreement_signed_at (a nil timestamp means
  # unsigned), so the boolean is dropped and inferred from the timestamp instead.
  def up
    remove_column :scholarships, :agreement_signed, if_exists: true
  end

  def down
    unless column_exists?(:scholarships, :agreement_signed)
      add_column :scholarships, :agreement_signed, :boolean, default: false, null: false
      execute "UPDATE scholarships SET agreement_signed = TRUE WHERE agreement_signed_at IS NOT NULL"
    end
  end
end
