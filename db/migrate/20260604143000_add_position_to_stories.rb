class AddPositionToStories < ActiveRecord::Migration[8.1]
  def up
    add_column :stories, :position, :integer
    add_index :stories, [ :featured, :position ]

    # Backfill a contiguous 1..n sequence within each featured group so the
    # positioning gem (scoped on :featured) has a valid starting state.
    execute <<~SQL.squish
      UPDATE stories s
      JOIN (
        SELECT id, ROW_NUMBER() OVER (PARTITION BY featured ORDER BY created_at, id) AS rn
        FROM stories
      ) ranked ON ranked.id = s.id
      SET s.position = ranked.rn
    SQL

    change_column_null :stories, :position, false
  end

  def down
    remove_index :stories, [ :featured, :position ], if_exists: true
    remove_column :stories, :position, if_exists: true
  end
end
