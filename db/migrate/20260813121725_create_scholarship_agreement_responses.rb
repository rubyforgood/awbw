class CreateScholarshipAgreementResponses < ActiveRecord::Migration[8.1]
  # Append-only log of each agreement transition; scholarships.agreement_response_status
  # (added next) caches the latest row's status.
  def up
    create_table :scholarship_agreement_responses do |t|
      t.references :scholarship, null: false, foreign_key: true
      t.string :status, null: false
      t.text :reason
      t.datetime :responded_at, null: false
      t.string :responder
      t.integer :amount_cents
      t.timestamps
    end
  end

  def down
    drop_table :scholarship_agreement_responses, if_exists: true
  end
end
