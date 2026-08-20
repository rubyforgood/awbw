class AddHideEventCardToNotifications < ActiveRecord::Migration[8.0]
  def up
    return if column_exists?(:notifications, :hide_event_card)

    # When true, the bulk reminder email (event_registration_reminder) omits the
    # grey event-details card. Set per-send from the compose page; defaults false
    # so existing reminders keep showing the card. Resends carry the stored value.
    add_column :notifications, :hide_event_card, :boolean, default: false, null: false
  end

  def down
    remove_column :notifications, :hide_event_card, if_exists: true
  end
end
