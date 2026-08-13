class TrimScholarshipAgreementCacheAndLinkResponseNotification < ActiveRecord::Migration[8.1]
  # The scholarship keeps only the denormalized agreement_response_status (needed
  # for SQL/totals). The latest response's timestamp + reason live on the response
  # row, so the two cache columns are dropped. A decline's response row links to
  # the FYI notification it produced.
  def up
    # notifications.id is an integer PK, so the FK column must match.
    add_reference :scholarship_agreement_responses, :notification, type: :integer, null: true, foreign_key: true unless column_exists?(:scholarship_agreement_responses, :notification_id)
    remove_column :scholarships, :agreement_responded_at, if_exists: true
    remove_column :scholarships, :agreement_response_reason, if_exists: true
  end

  def down
    add_column :scholarships, :agreement_responded_at, :datetime unless column_exists?(:scholarships, :agreement_responded_at)
    add_column :scholarships, :agreement_response_reason, :text unless column_exists?(:scholarships, :agreement_response_reason)

    # Rebuild the cache from each scholarship's most recent response.
    execute <<~SQL.squish
      UPDATE scholarships s
      JOIN (
        SELECT r.scholarship_id, r.responded_at, r.reason
        FROM scholarship_agreement_responses r
        JOIN (
          SELECT scholarship_id, MAX(responded_at) AS max_at
          FROM scholarship_agreement_responses GROUP BY scholarship_id
        ) m ON m.scholarship_id = r.scholarship_id AND m.max_at = r.responded_at
      ) latest ON latest.scholarship_id = s.id
      SET s.agreement_responded_at = latest.responded_at, s.agreement_response_reason = latest.reason
    SQL

    remove_reference :scholarship_agreement_responses, :notification, foreign_key: true, if_exists: true
  end
end
