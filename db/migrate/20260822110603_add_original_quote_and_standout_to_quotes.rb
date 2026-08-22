class AddOriginalQuoteAndStandoutToQuotes < ActiveRecord::Migration[7.2]
  def up
    add_column :quotes, :original_quote, :text, size: :long unless column_exists?(:quotes, :original_quote)
    unless column_exists?(:quotes, :standout)
      add_column :quotes, :standout, :boolean, default: false, null: false
    end
    add_index :quotes, :standout unless index_exists?(:quotes, :standout)
  end

  def down
    remove_index :quotes, :standout if index_exists?(:quotes, :standout)
    remove_column :quotes, :standout if column_exists?(:quotes, :standout)
    remove_column :quotes, :original_quote if column_exists?(:quotes, :original_quote)
  end
end
