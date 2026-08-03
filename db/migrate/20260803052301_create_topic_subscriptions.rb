class CreateTopicSubscriptions < ActiveRecord::Migration[8.1]
  def up
    create_table :topic_subscriptions do |t|
      t.references :person, null: false, foreign_key: true
      # Topic the person subscribed to, constrained by TopicSubscription::TOPICS.
      t.string :topic, null: false, default: "facilitator_trainings"
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
    add_index :topic_subscriptions, :topic
    add_index :topic_subscriptions, :unsubscribed_at
    add_index :topic_subscriptions, :created_by_id
    add_index :topic_subscriptions, :updated_by_id
  end

  def down
    drop_table :topic_subscriptions, if_exists: true
  end
end
