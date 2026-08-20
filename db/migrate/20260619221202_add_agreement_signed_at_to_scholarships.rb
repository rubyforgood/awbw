class AddAgreementSignedAtToScholarships < ActiveRecord::Migration[8.1]
  def up
    add_column :scholarships, :agreement_signed_at, :datetime unless column_exists?(:scholarships, :agreement_signed_at)
  end

  def down
    remove_column :scholarships, :agreement_signed_at, if_exists: true
  end
end
