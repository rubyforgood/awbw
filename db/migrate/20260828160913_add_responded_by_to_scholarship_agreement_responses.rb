class AddRespondedByToScholarshipAgreementResponses < ActiveRecord::Migration[8.1]
  def up
    # users.id is an integer, so the reference must match to allow the foreign key.
    remove_column :scholarship_agreement_responses, :responded_by_id, if_exists: true
    add_reference :scholarship_agreement_responses, :responded_by, type: :integer, null: true, index: true
    add_foreign_key :scholarship_agreement_responses, :users, column: :responded_by_id
  end

  def down
    if foreign_key_exists?(:scholarship_agreement_responses, column: :responded_by_id)
      remove_foreign_key :scholarship_agreement_responses, column: :responded_by_id
    end
    remove_reference :scholarship_agreement_responses, :responded_by, if_exists: true
  end
end
