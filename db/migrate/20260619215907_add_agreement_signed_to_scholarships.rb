class AddAgreementSignedToScholarships < ActiveRecord::Migration[8.1]
  def up
    add_column :scholarships, :agreement_signed, :boolean, default: false, null: false unless column_exists?(:scholarships, :agreement_signed)
  end

  def down
    remove_column :scholarships, :agreement_signed, if_exists: true
  end
end
