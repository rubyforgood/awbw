class AddEventSelectorToTopicSubscriptionTypes < ActiveRecord::Migration[8.1]
  def up
    add_column :topic_subscription_types, :event_selector, :boolean, null: false, default: false

    # Facilitator trainings is the one canonical topic tied to events; everything
    # else (news, resources, …) has no event dimension.
    execute("UPDATE topic_subscription_types SET event_selector = TRUE WHERE `key` = 'facilitator_trainings'")
  end

  def down
    remove_column :topic_subscription_types, :event_selector, if_exists: true
  end
end
