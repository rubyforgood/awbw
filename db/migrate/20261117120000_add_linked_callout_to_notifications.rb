class AddLinkedCalloutToNotifications < ActiveRecord::Migration[8.1]
  # A bulk reminder can carry a button straight to one of the event's ticket
  # callouts (or one resource on it). Stored on the notification so a resend
  # rebuilds the same email. Nullified when the callout/resource goes away —
  # the email then just drops the button.
  def change
    add_reference :notifications, :linked_callout, type: :bigint, null: true,
      foreign_key: { to_table: :registration_ticket_callouts, on_delete: :nullify }
    add_reference :notifications, :linked_resource, type: :integer, null: true,
      foreign_key: { to_table: :resources, on_delete: :nullify }
  end
end
