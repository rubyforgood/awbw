class AddAuthorToWorkshopLogsAndReports < ActiveRecord::Migration[8.1]
  # Bring workshop logs and monthly reports into the author-credit system (an
  # explicit Person author + the credit-preference snapshot AuthorCreditable
  # stores), matching workshops/stories/variations. Nullable, no backfill — the
  # legacy credit derives from created_by.person at read time.
  def up
    add_author_columns(:workshop_logs)
    add_author_columns(:reports)
  end

  def down
    remove_author_columns(:reports)
    remove_author_columns(:workshop_logs)
  end

  private

  def add_author_columns(table)
    add_column table, :author_credit_preference, :string unless column_exists?(table, :author_credit_preference)
    add_column table, :author_id, :bigint unless column_exists?(table, :author_id)
    add_index table, :author_id unless index_exists?(table, :author_id)
    unless foreign_key_exists?(table, :people, column: :author_id)
      add_foreign_key table, :people, column: :author_id
    end
  end

  def remove_author_columns(table)
    remove_foreign_key table, :people, column: :author_id, if_exists: true
    remove_index table, :author_id, if_exists: true
    remove_column table, :author_id, if_exists: true
    remove_column table, :author_credit_preference, if_exists: true
  end
end
