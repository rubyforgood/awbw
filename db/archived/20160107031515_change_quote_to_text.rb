class ChangeQuoteToText < ActiveRecord::Migration[4.2]
  def up
    change_column :quotes, :quote, :text
  end

  def down
    change_column :quotes, :quote, :string
  end
end
