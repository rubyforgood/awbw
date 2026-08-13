class ReplaceScholarshipAgreementSignedAtWithResponseStatus < ActiveRecord::Migration[8.1]
  # Replace the single agreement_signed_at timestamp with a tri-state status
  # (pending/accepted/declined). The signed date isn't lost — it's seeded onto a
  # response row (created in the previous migration) as the "accepted" response.
  def up
    add_column :scholarships, :agreement_response_status, :string, null: false, default: "pending"

    execute <<~SQL.squish
      UPDATE scholarships SET agreement_response_status = 'accepted' WHERE agreement_signed_at IS NOT NULL
    SQL

    # Seed the history: each already-signed award becomes an "accepted" response,
    # preserving when it was signed.
    execute <<~SQL.squish
      INSERT INTO scholarship_agreement_responses
        (scholarship_id, status, responded_at, responder, amount_cents, created_at, updated_at)
      SELECT id, 'accepted', agreement_signed_at, 'system', amount_cents, NOW(), NOW()
      FROM scholarships
      WHERE agreement_signed_at IS NOT NULL
    SQL

    remove_column :scholarships, :agreement_signed_at
  end

  def down
    add_column :scholarships, :agreement_signed_at, :datetime

    # Rebuild the timestamp from the latest accepted response.
    execute <<~SQL.squish
      UPDATE scholarships s
      JOIN (
        SELECT scholarship_id, MAX(responded_at) AS max_at
        FROM scholarship_agreement_responses
        WHERE status = 'accepted'
        GROUP BY scholarship_id
      ) a ON a.scholarship_id = s.id
      SET s.agreement_signed_at = a.max_at
      WHERE s.agreement_response_status = 'accepted'
    SQL

    remove_column :scholarships, :agreement_response_status
  end
end
