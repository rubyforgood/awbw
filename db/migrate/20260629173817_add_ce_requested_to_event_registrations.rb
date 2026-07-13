class AddCeRequestedToEventRegistrations < ActiveRecord::Migration[8.1]
  # The CE "Requested" intent flag, mirroring scholarship_requested / w9_requested
  # / invoice_requested. It's the toggle the registrant/admin sets; the
  # ContinuingEducationRegistration record is the fulfillment, created from it.
  def up
    unless column_exists?(:event_registrations, :ce_requested)
      add_column :event_registrations, :ce_requested, :boolean, null: false, default: false
    end
  end

  def down
    remove_column :event_registrations, :ce_requested, if_exists: true
  end
end
