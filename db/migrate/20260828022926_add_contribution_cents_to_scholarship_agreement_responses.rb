class AddContributionCentsToScholarshipAgreementResponses < ActiveRecord::Migration[8.1]
  def up
    add_column :scholarship_agreement_responses, :contribution_cents, :integer
  end

  def down
    remove_column :scholarship_agreement_responses, :contribution_cents, if_exists: true
  end
end
