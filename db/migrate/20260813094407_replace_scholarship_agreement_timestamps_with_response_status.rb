class ReplaceScholarshipAgreementTimestampsWithResponseStatus < ActiveRecord::Migration[8.1]
  # Collapses the two mutually-exclusive agreement timestamps (agreement_signed_at
  # and the never-released agreement_declined_at/reason) into a single tri-state
  # status column + one timestamp + one reason. Guarded so it runs on a fresh DB
  # (where the decline columns never existed) and on a branch DB that already has
  # them.
  def up
    add_column :scholarships, :agreement_response_status, :string, null: false, default: "pending" unless column_exists?(:scholarships, :agreement_response_status)
    add_column :scholarships, :agreement_responded_at, :datetime unless column_exists?(:scholarships, :agreement_responded_at)
    add_column :scholarships, :agreement_response_reason, :text unless column_exists?(:scholarships, :agreement_response_reason)

    if column_exists?(:scholarships, :agreement_signed_at)
      execute <<~SQL.squish
        UPDATE scholarships
        SET agreement_response_status = 'accepted', agreement_responded_at = agreement_signed_at
        WHERE agreement_signed_at IS NOT NULL
      SQL
    end

    if column_exists?(:scholarships, :agreement_declined_at)
      execute <<~SQL.squish
        UPDATE scholarships
        SET agreement_response_status = 'declined',
            agreement_responded_at = agreement_declined_at,
            agreement_response_reason = agreement_declined_reason
        WHERE agreement_declined_at IS NOT NULL
      SQL
    end

    remove_column :scholarships, :agreement_signed_at, if_exists: true
    remove_column :scholarships, :agreement_declined_at, if_exists: true
    remove_column :scholarships, :agreement_declined_reason, if_exists: true
  end

  def down
    add_column :scholarships, :agreement_signed_at, :datetime unless column_exists?(:scholarships, :agreement_signed_at)
    add_column :scholarships, :agreement_declined_at, :datetime unless column_exists?(:scholarships, :agreement_declined_at)
    add_column :scholarships, :agreement_declined_reason, :text unless column_exists?(:scholarships, :agreement_declined_reason)

    execute <<~SQL.squish
      UPDATE scholarships SET agreement_signed_at = agreement_responded_at
      WHERE agreement_response_status = 'accepted'
    SQL
    execute <<~SQL.squish
      UPDATE scholarships
      SET agreement_declined_at = agreement_responded_at, agreement_declined_reason = agreement_response_reason
      WHERE agreement_response_status = 'declined'
    SQL

    remove_column :scholarships, :agreement_response_status, if_exists: true
    remove_column :scholarships, :agreement_responded_at, if_exists: true
    remove_column :scholarships, :agreement_response_reason, if_exists: true
  end
end
