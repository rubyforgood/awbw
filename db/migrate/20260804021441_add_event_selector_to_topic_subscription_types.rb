class AddEventSelectorToTopicSubscriptionTypes < ActiveRecord::Migration[8.1]
  # No data backfill: event_selector is set per topic by the seed
  # (TopicSubscriptionType::CANONICAL). Facilitator trainings is the one canonical
  # event-tied topic; news/resources have no event dimension.
  def change
    add_column :topic_subscription_types, :event_selector, :boolean, null: false, default: false
  end
end
