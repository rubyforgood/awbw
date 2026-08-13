class ReplaceScholarshipAgreementSignedAtWithResponseStatus < ActiveRecord::Migration[8.1]
  # Replace the single agreement_signed_at timestamp with a tri-state status
  # (pending/accepted/declined). No data backfill: there are no signed agreements
  # in production, so every existing row correctly defaults to "pending". Going
  # forward the date + reason live on the response rows, not on the scholarship.
  def up
    add_column :scholarships, :agreement_response_status, :string, null: false, default: "pending"
    remove_column :scholarships, :agreement_signed_at
  end

  def down
    add_column :scholarships, :agreement_signed_at, :datetime
    remove_column :scholarships, :agreement_response_status
  end
end
