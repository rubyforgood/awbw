class CreateNotificationCompositions < ActiveRecord::Migration[8.1]
  def change
    create_table :notification_compositions do |t|
      # kind = draft | template (see NotificationComposition::KINDS).
      # A string (not a boolean/STI `type`) so a future "scheduled" kind is additive.
      t.string :kind, null: false
      # scope_type = general | event. Independent of event_id: an event-reminder
      # *template* is event-scoped but bound to no specific event until used.
      t.string :scope_type, null: false, default: "general"
      t.string :name
      t.references :user, null: false, index: true
      t.references :event, index: true

      # EmailContent — discrete columns. Presence is the on/off flag (no _enabled
      # columns): a present cta_label shows the button, a present grey_box_text
      # shows the callout. cta_url null = the recipient's portal profile.
      t.string :subject
      t.text :body
      t.string :cta_label
      t.string :cta_url
      t.text :grey_box_text

      # AudienceDefinition — a re-resolvable recipe, never a frozen recipient list.
      # recipient_segments = ordered [{ field, value, join }]; overrides split by
      # direction so a single list never has to mean both "force in" and "force out".
      t.json :recipient_segments
      t.json :recipient_added_ids
      t.json :recipient_excluded_ids

      t.timestamps
    end
  end
end
