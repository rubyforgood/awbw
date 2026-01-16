class AddActionTextMentions < ActiveRecord::Migration[8.1]
  def change
    create_table :action_text_mentions do |t|
      t.references :action_text_rich_text,
                   null: false,
                   foreign_key: { to_table: :action_text_rich_texts },
                   type: :bigint

      t.references :mentionable,
                   null: false,
                   polymorphic: true,
                   index: true

      t.timestamps
    end

    add_index :action_text_mentions,
              [ :action_text_rich_text_id, :mentionable_type, :mentionable_id ],
              unique: true,
              name: "index_at_mentions_on_rich_text_and_mentionable"
  end
end
