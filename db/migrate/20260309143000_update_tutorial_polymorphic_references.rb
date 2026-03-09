class UpdateTutorialPolymorphicReferences < ActiveRecord::Migration[8.0]
  def up
    polymorphic_tables = {
      bookmarks: :bookmarkable_type,
      assets: :owner_type,
      action_text_rich_texts: :record_type,
      active_storage_attachments: :record_type,
      categorizable_items: :categorizable_type,
      sectorable_items: :sectorable_type,
      comments: :commentable_type,
      ahoy_events: :resource_type,
      notifications: :noticeable_type
    }

    polymorphic_tables.each do |table, column|
      execute <<~SQL.squish
        UPDATE #{table}
        SET #{column} = 'VideoRecording'
        WHERE #{column} = 'Tutorial'
      SQL
    end
  end

  def down
    polymorphic_tables = {
      bookmarks: :bookmarkable_type,
      assets: :owner_type,
      action_text_rich_texts: :record_type,
      active_storage_attachments: :record_type,
      categorizable_items: :categorizable_type,
      sectorable_items: :sectorable_type,
      comments: :commentable_type,
      ahoy_events: :resource_type,
      notifications: :noticeable_type
    }

    polymorphic_tables.each do |table, column|
      execute <<~SQL.squish
        UPDATE #{table}
        SET #{column} = 'Tutorial'
        WHERE #{column} = 'VideoRecording'
      SQL
    end
  end
end
