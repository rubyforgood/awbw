class CreateScholarshipAgreementResponses < ActiveRecord::Migration[8.1]
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

    # Seed one row per already-decided scholarship so existing accepted/declined
    # awards show an initial history entry (going-forward responses are logged by
    # the model).
    execute <<~SQL.squish
      INSERT INTO scholarship_agreement_responses
        (scholarship_id, status, reason, responded_at, responder, amount_cents, created_at, updated_at)
      SELECT id, agreement_response_status, agreement_response_reason,
             COALESCE(agreement_responded_at, updated_at), 'system', amount_cents,
             NOW(), NOW()
      FROM scholarships
      WHERE agreement_response_status <> 'pending'
    SQL
  end

  def down
    drop_table :scholarship_agreement_responses, if_exists: true
  end
end
