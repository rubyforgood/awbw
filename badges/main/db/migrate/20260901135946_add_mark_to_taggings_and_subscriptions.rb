class AddMarkToTaggingsAndSubscriptions < ActiveRecord::Migration[8.1]
  def up
    # The boolean lives on the tagging/subscription; the human label for what it
    # means is configured per tag/topic.
    add_column :staff_taggings, :marked, :boolean, default: false, null: false
    add_column :topic_subscriptions, :marked, :boolean, default: false, null: false
    add_column :staff_tags, :mark_label, :string
    add_column :topic_subscription_types, :mark_label, :string
    add_index :staff_taggings, :marked
    add_index :topic_subscriptions, :marked
  end

  def down
    remove_index :staff_taggings, :marked, if_exists: true
    remove_index :topic_subscriptions, :marked, if_exists: true
    remove_column :staff_taggings, :marked, if_exists: true
    remove_column :topic_subscriptions, :marked, if_exists: true
    remove_column :staff_tags, :mark_label, if_exists: true
    remove_column :topic_subscription_types, :mark_label, if_exists: true
  end
end
