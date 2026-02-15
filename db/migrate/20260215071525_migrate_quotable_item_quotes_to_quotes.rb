class MigrateQuotableItemQuotesToQuotes < ActiveRecord::Migration[8.1]
  def up
    # Copy quotable associations from quotable_item_quotes to quotes
    execute <<-SQL.squish
      UPDATE quotes
      INNER JOIN quotable_item_quotes ON quotes.id = quotable_item_quotes.quote_id
      SET quotes.quotable_id = quotable_item_quotes.quotable_id,
          quotes.quotable_type = quotable_item_quotes.quotable_type
    SQL
  end

  def down
    # Rollback: clear quotable associations from quotes
    # Note: This doesn't restore the quotable_item_quotes records
    # as they should still exist for rollback purposes
    execute <<-SQL.squish
      UPDATE quotes
      SET quotes.quotable_id = NULL,
          quotes.quotable_type = NULL
    SQL
  end
end
