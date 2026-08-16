class ReplaceScholarshipAgreementSignedAtWithResponseStatus < ActiveRecord::Migration[8.1]
  # Replace agreement_signed_at with a tri-state status. No backfill — there are no
  # signed agreements in production, so existing rows correctly default to pending.
  def up
    add_column :scholarships, :agreement_response_status, :string, null: false, default: "pending"
    remove_column :scholarships, :agreement_signed_at
  end

  def down
    add_column :scholarships, :agreement_signed_at, :datetime
    remove_column :scholarships, :agreement_response_status
  end
end
