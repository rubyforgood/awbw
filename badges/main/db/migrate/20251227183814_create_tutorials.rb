class CreateTutorials < ActiveRecord::Migration[8.1]
  def up
    create_table :tutorials do |t|
      t.string :title, index: true
      t.text :body
      t.boolean :featured, null: false, default: false, index: true
      t.boolean :published, null: false, default: false, index: true
      t.integer :position, null: false, default: 10
      t.string :youtube_url

      t.timestamps
    end

    execute <<~SQL
      ALTER TABLE community_news
      ADD FULLTEXT INDEX index_community_news_on_body (body);
    SQL
  end

  def down
    execute <<~SQL
      ALTER TABLE community_news
      DROP INDEX index_community_news_on_body;
    SQL

    drop_table :tutorials
  end
end
