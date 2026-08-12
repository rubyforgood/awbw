class AddAgreementDeclineToScholarships < ActiveRecord::Migration[8.1]
  def up
    add_column :scholarships, :agreement_declined_at, :datetime
    add_column :scholarships, :agreement_declined_reason, :text
  end

  def down
    remove_column :scholarships, :agreement_declined_reason, if_exists: true
    remove_column :scholarships, :agreement_declined_at, if_exists: true
  end
end
