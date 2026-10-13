class AddReviewAndTargetToProfileChangeRequests < ActiveRecord::Migration[8.0]
  def change
    add_column :profile_change_requests, :reviewer_note, :text
    add_reference :profile_change_requests, :organization, type: :integer, null: true, foreign_key: true
    add_reference :profile_change_requests, :affiliation, type: :integer, null: true, foreign_key: true
  end
end
