class CreateScholarshipAgreementResponses < ActiveRecord::Migration[8.1]
  # Append-only log of each agreement transition (accept ↔ decline ↔ re-offer).
  # The scholarship's agreement_response_status (added next) is the denormalized
  # cache of the latest row here; responded_at + reason live here, not on the
  # scholarship.
  def up
    create_table :scholarship_agreement_responses do |t|
      t.references :scholarship, null: false, foreign_key: true
      t.string :status, null: false
      t.text :reason
      t.datetime :responded_at, null: false
      t.string :responder
      t.integer :amount_cents
      # notifications.id is an integer PK, so the FK column must match.
      t.references :notification, type: :integer, null: true, foreign_key: true
      t.timestamps
    end
  end

  def down
    drop_table :scholarship_agreement_responses, if_exists: true
  end
end
