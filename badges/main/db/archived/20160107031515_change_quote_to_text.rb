class ChangeQuoteToText < ActiveRecord::Migration
  def up
    change_column :quotes, :quote, :text
  end

  def down
    change_column :quotes, :quote, :string
  end
end
