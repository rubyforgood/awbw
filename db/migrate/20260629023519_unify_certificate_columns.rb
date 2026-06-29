class UnifyCertificateColumns < ActiveRecord::Migration[8.1]
  # Certificates are handled the same way on EventRegistration and
  # ContinuingEducationRegistration: availability is computed (#certificate_available?)
  # and delivery is recorded with certificate_sent_at. Payment is computed too, so a
  # CE registration no longer needs a stored status, and issued_at is redundant with
  # certificate_sent_at (sending the email is how a certificate is issued).
  def up
    add_column :event_registrations, :certificate_sent_at, :datetime unless column_exists?(:event_registrations, :certificate_sent_at)
    remove_column :continuing_education_registrations, :status, if_exists: true
    remove_column :continuing_education_registrations, :issued_at, if_exists: true
  end

  def down
    remove_column :event_registrations, :certificate_sent_at, if_exists: true
    add_column :continuing_education_registrations, :issued_at, :datetime unless column_exists?(:continuing_education_registrations, :issued_at)
    unless column_exists?(:continuing_education_registrations, :status)
      add_column :continuing_education_registrations, :status, :string, null: false, default: "requested"
    end
  end
end
