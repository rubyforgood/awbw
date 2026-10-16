class AddProfessionalLicenseToProfileChangeRequests < ActiveRecord::Migration[8.1]
  def up
    add_reference :profile_change_requests, :professional_license, foreign_key: true, null: true
  end

  def down
    remove_foreign_key :profile_change_requests, :professional_licenses, if_exists: true
    remove_reference :profile_change_requests, :professional_license, if_exists: true
  end
end
