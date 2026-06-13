class AddAutoshowRegistrationDetailsToEvents < ActiveRecord::Migration[8.1]
  # Opt-in toggle for the structured "at a glance" details panel (dates, time,
  # platform, fee, deadline) on the public registration page. Named after the
  # existing autoshow_* event display flags. Off by default so existing events
  # are unchanged; admins enable it from the Registration Form section.
  def up
    unless column_exists?(:events, :autoshow_registration_details)
      add_column :events, :autoshow_registration_details, :boolean, default: false, null: false
    end
  end

  def down
    remove_column :events, :autoshow_registration_details, if_exists: true
  end
end
