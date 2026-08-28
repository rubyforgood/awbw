class AddOrganizationToTopicSubscriptions < ActiveRecord::Migration[8.1]
  def up
    return if column_exists?(:topic_subscriptions, :organization_id)

    # Optional narrowing: an organization the subscription is about. Null = the
    # topic broadly, not tied to any organization.
    add_reference :topic_subscriptions, :organization, null: true, foreign_key: true, type: :integer
  end

  def down
    remove_reference :topic_subscriptions, :organization, foreign_key: true, if_exists: true
  end
end
