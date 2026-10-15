class AddProposedEmailTypeToProfileChangeRequests < ActiveRecord::Migration[8.1]
  def up
    add_column :profile_change_requests, :proposed_email_type, :string
  end

  def down
    remove_column :profile_change_requests, :proposed_email_type, if_exists: true
  end
end
