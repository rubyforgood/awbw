class AddUniqueIndexesToTaggings < ActiveRecord::Migration[8.1]
  disable_ddl_transaction! # indexes + data checks can be expensive

  def up
    assert_no_duplicate_sectorable_items!
    assert_no_duplicate_categorizable_items!

    add_index :sectorable_items,
              [ :sector_id, :sectorable_type, :sectorable_id ],
              unique: true,
              name: "index_sectorable_items_uniqueness"

    add_index :categorizable_items,
              [ :category_id, :categorizable_type, :categorizable_id ],
              unique: true,
              name: "index_categorizable_items_uniqueness"
  end

  def down
    remove_index :sectorable_items,
                 name: "index_sectorable_items_uniqueness"

    remove_index :categorizable_items,
                 name: "index_categorizable_items_uniqueness"
  end

  private

  def assert_no_duplicate_sectorable_items!
    duplicates = execute(<<~SQL).to_a
    SELECT
      sector_id,
      sectorable_type,
      sectorable_id,
      COUNT(*) AS count
    FROM sectorable_items
    GROUP BY sector_id, sectorable_type, sectorable_id
    HAVING COUNT(*) > 1
    LIMIT 1
  SQL

    return if duplicates.empty?

    row = duplicates.first

    raise ActiveRecord::IrreversibleMigration, <<~MSG
    Cannot add unique index to sectorable_items.

    Duplicate records exist for:
      sector_id=#{row[0]}
      sectorable_type=#{row[1]}
      sectorable_id=#{row[2]}

    Clean up duplicates before running this migration.
  MSG
  end

  def assert_no_duplicate_categorizable_items!
    duplicates = execute(<<~SQL).to_a
      SELECT
        category_id,
        categorizable_type,
        categorizable_id,
        COUNT(*) AS count
      FROM categorizable_items
      GROUP BY category_id, categorizable_type, categorizable_id
      HAVING COUNT(*) > 1
      LIMIT 1
    SQL
    return if duplicates.empty?

    row = duplicates.first

    raise ActiveRecord::IrreversibleMigration, <<~MSG
      Cannot add unique index to categorizable_items.
      Duplicate records exist for:
        category_id=#{row[0]}
        categorizable_type=#{row[1]}
        categorizable_id=#{row[2]}
      Clean up duplicates before running this migration.
    MSG
  end
end
