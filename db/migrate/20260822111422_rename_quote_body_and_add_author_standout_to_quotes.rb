class RenameQuoteBodyAndAddAuthorStandoutToQuotes < ActiveRecord::Migration[7.2]
  def up
    rename_column :quotes, :quote, :body if column_exists?(:quotes, :quote)

    add_column :quotes, :original_body, :text, size: :long unless column_exists?(:quotes, :original_body)

    unless column_exists?(:quotes, :standout)
      add_column :quotes, :standout, :boolean, default: false, null: false
    end
    add_index :quotes, :standout unless index_exists?(:quotes, :standout)

    add_column :quotes, :author_id, :bigint unless column_exists?(:quotes, :author_id)
    add_column :quotes, :author_credit_preference, :string unless column_exists?(:quotes, :author_credit_preference)
    add_index :quotes, :author_id unless index_exists?(:quotes, :author_id)
    unless foreign_key_exists?(:quotes, :people, column: :author_id)
      add_foreign_key :quotes, :people, column: :author_id
    end
  end

  def down
    remove_foreign_key :quotes, column: :author_id if foreign_key_exists?(:quotes, :people, column: :author_id)
    remove_index :quotes, :author_id if index_exists?(:quotes, :author_id)
    remove_column :quotes, :author_credit_preference if column_exists?(:quotes, :author_credit_preference)
    remove_column :quotes, :author_id if column_exists?(:quotes, :author_id)

    remove_index :quotes, :standout if index_exists?(:quotes, :standout)
    remove_column :quotes, :standout if column_exists?(:quotes, :standout)

    remove_column :quotes, :original_body if column_exists?(:quotes, :original_body)

    rename_column :quotes, :body, :quote if column_exists?(:quotes, :body)
  end
end
