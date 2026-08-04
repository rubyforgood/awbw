class CreateTopicSubscriptions < ActiveRecord::Migration[8.1]
  def up
    create_table :topic_subscription_types do |t|
      t.string :name, null: false
      # Stable slug for code lookups (e.g. the interested_in_more mapping),
      # independent of the admin-editable display name.
      t.string :key, null: false
      t.text :description
      # Retire a topic without deleting it (types in use can't be destroyed):
      # archived_at IS NULL = available in pickers.
      t.datetime :archived_at
      t.bigint :created_by_id
      t.bigint :updated_by_id
      t.timestamps
    end
    add_index :topic_subscription_types, :name, unique: true
    add_index :topic_subscription_types, :key, unique: true
    add_index :topic_subscription_types, :archived_at

    create_table :topic_subscriptions do |t|
      t.references :person, null: false, foreign_key: true
      t.references :topic_subscription_type, null: false, foreign_key: true
      # Optional narrowing: a specific event the subscription is about. Null =
      # the topic broadly (e.g. all future trainings).
      t.references :interested_event, null: true, foreign_key: { to_table: :events }
      # Subscription state is a pair of timestamps (unsubscribed_at IS NULL =
      # active), mirroring people.mailing_list_consent_at — no status column.
      t.datetime :subscribed_at, null: false
      t.datetime :unsubscribed_at
      # Where the subscription came from (registration form, admin, import),
      # mirroring people.mailing_list_consent_source.
      t.string :source
      t.text :note
      t.bigint :created_by_id
      t.bigint :updated_by_id
      t.timestamps
    end
    add_index :topic_subscriptions, :unsubscribed_at
    add_index :topic_subscriptions, :created_by_id
    add_index :topic_subscriptions, :updated_by_id
  end

  def down
    drop_table :topic_subscriptions, if_exists: true
    drop_table :topic_subscription_types, if_exists: true
  end
end
