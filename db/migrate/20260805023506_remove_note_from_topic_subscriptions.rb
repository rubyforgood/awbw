class RemoveNoteFromTopicSubscriptions < ActiveRecord::Migration[8.1]
  # The free-text note field is replaced by polymorphic comments, which surface
  # on the person's aggregated comments page.
  def up
    remove_column :topic_subscriptions, :note, if_exists: true
  end

  def down
    add_column :topic_subscriptions, :note, :text unless column_exists?(:topic_subscriptions, :note)
  end
end
