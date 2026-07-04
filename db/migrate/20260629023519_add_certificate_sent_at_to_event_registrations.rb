class AddCertificateSentAtToEventRegistrations < ActiveRecord::Migration[8.1]
  # Certificate delivery is recorded the same way as on CE registrations: a
  # certificate_sent_at timestamp, set when the certificate email is sent.
  def up
    add_column :event_registrations, :certificate_sent_at, :datetime unless column_exists?(:event_registrations, :certificate_sent_at)
  end

  def down
    remove_column :event_registrations, :certificate_sent_at, if_exists: true
  end
end
